<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Photo;
use App\Models\Result;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class DownloadController extends Controller
{
    /**
     * Show customer mobile download portal when QR Code is scanned.
     */
    public function show(string $token)
    {
        $result = Result::where('qr_token', $token)
            ->with(['session.event', 'session.frame', 'session.filter', 'session.photos'])
            ->first();

        if (!$result) {
            return view('download_not_found');
        }

        $isExpired = now()->greaterThan($result->expires_at);
        $session = $result->session;
        $event = $session ? $session->event : null;

        $rawPhotos = $session ? $session->photos()->where('type', 'raw')->orderBy('id')->get() : collect();

        $stripUrl = $result->final_url ? asset('storage/' . $result->final_url) : null;
        $gifUrl = $result->gif_url ? asset('storage/' . $result->gif_url) : null;

        // Calculate days left
        $daysLeft = max(0, (int) now()->diffInDays($result->expires_at, false));
        $hoursLeft = max(0, (int) now()->diffInHours($result->expires_at, false));

        return view('download', [
            'result'     => $result,
            'session'    => $session,
            'event'      => $event,
            'rawPhotos'  => $rawPhotos,
            'stripUrl'   => $stripUrl,
            'gifUrl'     => $gifUrl,
            'isExpired'  => $isExpired,
            'daysLeft'   => $daysLeft,
            'hoursLeft'  => $hoursLeft,
            'token'      => $token,
        ]);
    }

    /**
     * Download High-Res Photo Strip PNG.
     */
    public function downloadStrip(string $token)
    {
        $result = Result::where('qr_token', $token)->firstOrFail();
        if (now()->greaterThan($result->expires_at)) {
            abort(403, 'Masa aktif foto telah berakhir.');
        }

        $filePath = Storage::disk('public')->path($result->final_url);
        if (!file_exists($filePath)) {
            $filePath = public_path('storage/' . $result->final_url);
        }

        if (!file_exists($filePath)) {
            abort(404, 'File foto tidak ditemukan.');
        }

        $filename = 'FakultasKopi_PhotoStrip_' . date('Ymd_His') . '.png';
        return response()->download($filePath, $filename, [
            'Content-Type' => 'image/png',
        ]);
    }

    /**
     * Download Looping Animated GIF.
     */
    public function downloadGif(string $token)
    {
        $result = Result::where('qr_token', $token)->firstOrFail();
        if (now()->greaterThan($result->expires_at)) {
            abort(403, 'Masa aktif foto telah berakhir.');
        }

        $filePath = Storage::disk('public')->path($result->gif_url);
        if (!file_exists($filePath)) {
            $filePath = public_path('storage/' . $result->gif_url);
        }

        if (!file_exists($filePath)) {
            abort(404, 'File animasi tidak ditemukan.');
        }

        $filename = 'FakultasKopi_Motion_' . date('Ymd_His') . '.gif';
        return response()->download($filePath, $filename, [
            'Content-Type' => 'image/gif',
        ]);
    }

    /**
     * Download individual single raw photo.
     */
    public function downloadPhoto(string $token, int $photoId)
    {
        $result = Result::where('qr_token', $token)->firstOrFail();
        if (now()->greaterThan($result->expires_at)) {
            abort(403, 'Masa aktif foto telah berakhir.');
        }

        $photo = Photo::where('session_id', $result->session_id)->where('id', $photoId)->firstOrFail();

        $filePath = Storage::disk('public')->path($photo->file_url);
        if (!file_exists($filePath)) {
            $filePath = public_path('storage/' . $photo->file_url);
        }

        if (!file_exists($filePath)) {
            abort(404, 'Foto tidak ditemukan.');
        }

        $filename = 'FakultasKopi_Pose_' . $photoId . '_' . date('Ymd') . '.jpg';
        return response()->download($filePath, $filename);
    }
}
