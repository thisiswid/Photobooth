<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Photo;
use App\Models\Result;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class DownloadController extends Controller
{
    /**
     * Ambil Result yang belum kedaluwarsa, atau hentikan permintaan.
     */
    protected function activeResult(string $token): Result
    {
        $result = Result::where('qr_token', $token)->firstOrFail();

        abort_if(
            !$result->expires_at || now()->greaterThan($result->expires_at),
            403,
            'Masa aktif foto telah berakhir.'
        );

        return $result;
    }

    /**
     * Ubah path relatif di database menjadi path berkas nyata.
     *
     * Penjagaan traversal di sini bersifat berlapis: SessionController sudah
     * berhenti menerima `file_url` berupa string dari klien, tapi baris lama
     * yang terlanjur tersimpan masih bisa memuat '../'. Tanpa pemeriksaan ini
     * path seperti itu diteruskan apa adanya ke response()->download().
     */
    protected function safePath(?string $relative): string
    {
        abort_if(blank($relative), 404, 'Berkas tidak ditemukan.');

        $normalized = str_replace('\\', '/', $relative);

        abort_if(
            str_contains($normalized, '..')
                || str_starts_with($normalized, '/')
                || preg_match('#^[a-zA-Z]:#', $normalized) === 1,
            404,
            'Berkas tidak ditemukan.'
        );

        $root = realpath(Storage::disk('public')->path(''));
        $full = realpath(Storage::disk('public')->path($normalized));

        if ($full === false) {
            $fallback = realpath(public_path('storage/' . $normalized));
            $publicRoot = realpath(public_path('storage'));
            abort_if(
                $fallback === false || $publicRoot === false || !str_starts_with($fallback, $publicRoot),
                404,
                'Berkas tidak ditemukan.'
            );
            return $fallback;
        }

        abort_if($root === false || !str_starts_with($full, $root), 404, 'Berkas tidak ditemukan.');

        return $full;
    }

    /**
     * Awalan nama berkas mengikuti cafe pemilik sesi.
     *
     * Sebelumnya kelima method di bawah memakai 'FakultasKopi_' yang
     * di-hardcode, sehingga tamu cafe manapun mengunduh berkas bermerek
     * tenant pilot.
     */
    protected function filePrefix(Result $result): string
    {
        $name = $result->session?->cafe?->name
            ?? $result->session?->event?->name
            ?? 'Photobooth';

        return Str::studly(Str::slug($name, ' ')) ?: 'Photobooth';
    }

    /**
     * Portal unduhan pelanggan saat QR Code dipindai.
     */
    public function show(string $token)
    {
        $result = Result::where('qr_token', $token)
            ->with(['session.cafe', 'session.event', 'session.frame', 'session.filter', 'session.photos'])
            ->first();

        if (!$result) {
            return view('download_not_found');
        }

        $isExpired = !$result->expires_at || now()->greaterThanOrEqualTo($result->expires_at);
        $session = $result->session;
        $event = $session ? $session->event : null;
        $cafe = $session ? $session->cafe : null;
        $cafeName = $cafe ? $cafe->name : ($event ? $event->name : 'Photobooth');
        $hasFilter = $session && $session->filter_id;

        $rawPhotos = $session ? $session->photos()->where('type', 'raw')->orderBy('id')->get() : collect();

        $stripUrl = $result->final_url ? asset('storage/' . $result->final_url) : null;
        $rawStripUrl = $result->raw_final_url ? asset('storage/' . $result->raw_final_url) : $stripUrl;
        $videoUrl = $result->video_url ? asset('storage/' . $result->video_url) : null;
        $gifUrl = $result->gif_url ? asset('storage/' . $result->gif_url) : null;

        $daysLeft = max(0, (int) now()->diffInDays($result->expires_at, false));
        $hoursLeft = max(0, (int) now()->diffInHours($result->expires_at, false));

        return view('download', [
            'result'      => $result,
            'session'     => $session,
            'event'       => $event,
            'cafeName'    => $cafeName,
            'hasFilter'   => $hasFilter,
            'rawPhotos'   => $rawPhotos,
            'stripUrl'    => $stripUrl,
            'rawStripUrl' => $rawStripUrl,
            'videoUrl'    => $videoUrl,
            'gifUrl'      => $gifUrl,
            'isExpired'   => $isExpired,
            'daysLeft'    => $daysLeft,
            'hoursLeft'   => $hoursLeft,
            'token'       => $token,
        ]);
    }

    /**
     * Unduh Photo Strip PNG resolusi tinggi (dengan filter terpilih).
     */
    public function downloadStrip(string $token)
    {
        $result = $this->activeResult($token);
        $path = $this->safePath($result->final_url);

        return response()->download(
            $path,
            $this->filePrefix($result) . '_PhotoStrip_' . date('Ymd_His') . '.png',
            ['Content-Type' => 'image/png']
        );
    }

    /**
     * Unduh Photo Strip PNG asli (tanpa filter).
     */
    public function downloadRawStrip(string $token)
    {
        $result = $this->activeResult($token);
        $path = $this->safePath($result->raw_final_url ?: $result->final_url);

        return response()->download(
            $path,
            $this->filePrefix($result) . '_PhotoStrip_Original_' . date('Ymd_His') . '.png',
            ['Content-Type' => 'image/png']
        );
    }

    /**
     * Unduh video MP4.
     */
    public function downloadVideo(string $token)
    {
        $result = $this->activeResult($token);
        abort_if(!$result->video_url, 404, 'Video tidak tersedia.');
        $path = $this->safePath($result->video_url);

        return response()->download(
            $path,
            $this->filePrefix($result) . '_MotionVideo_' . date('Ymd_His') . '.mp4',
            ['Content-Type' => 'video/mp4']
        );
    }

    /**
     * Unduh GIF animasi.
     */
    public function downloadGif(string $token)
    {
        $result = $this->activeResult($token);
        $path = $this->safePath($result->gif_url);

        return response()->download(
            $path,
            $this->filePrefix($result) . '_Motion_' . date('Ymd_His') . '.gif',
            ['Content-Type' => 'image/gif']
        );
    }

    /**
     * Unduh satu foto mentah.
     */
    public function downloadPhoto(string $token, int $photoId)
    {
        $result = $this->activeResult($token);

        $photo = Photo::where('session_id', $result->session_id)
            ->where('id', $photoId)
            ->firstOrFail();

        $path = $this->safePath($photo->file_url);

        return response()->download(
            $path,
            $this->filePrefix($result) . '_Pose_' . $photoId . '_' . date('Ymd') . '.jpg'
        );
    }
}
