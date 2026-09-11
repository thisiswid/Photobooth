<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Photo;
use App\Models\Session;
use App\Models\TimerSetting;
use App\Models\Frame;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Handles session lifecycle for the Flutter customer app.
 *
 * Flow: POST /payments (bikin sesi + payment) -> webhook/status menandai LUNAS
 *       -> setFrame -> uploadPhotos -> generateResult -> finish
 *
 * Setiap endpoint di bawah menolak sesi yang pembayarannya belum lunas.
 * Tidak ada lagi pembuatan sesi otomatis: sesi hanya lahir dari alur pembayaran.
 */
class SessionController extends Controller
{
    /**
     * Ambil sesi yang pembayarannya sudah LUNAS, atau gagal dengan jelas.
     *
     * Menggantikan pola lama "kalau sesi tidak ditemukan, buat saja" yang
     * membuat siapa pun bisa memulai sesi tanpa membayar.
     */
    protected function resolvePaidSession($session): Session
    {
        $sessionModel = $session instanceof Session
            ? $session
            : (is_numeric($session) ? Session::find((int) $session) : null);

        abort_if(!$sessionModel, 404, 'Sesi tidak ditemukan.');

        $payment = Payment::where('session_id', $sessionModel->id)->latest('id')->first();

        abort_if(
            !$payment || $payment->status !== 'paid',
            402,
            'Sesi ini belum lunas. Selesaikan pembayaran terlebih dahulu.'
        );

        return $sessionModel;
    }

    /**
     * Hitung durasi sesi dari TimerSetting event, lalu cafe, lalu default.
     */
    protected function sessionDuration(?int $eventId, ?int $cafeId): int
    {
        $timerSetting = ($eventId
            ? TimerSetting::where('event_id', $eventId)->where('is_active', true)->first()
            : null) ?? TimerSetting::resolveForCafe($cafeId);

        return (int) ($timerSetting->session_timeout_seconds ?? 360);
    }

    protected function frameForSession(int $frameId, Session $session): Frame
    {
        return Frame::query()
            ->whereKey($frameId)
            ->whereHas('event', fn ($query) => $query->where('cafe_id', $session->cafe_id))
            ->when($session->event_id, fn ($query) => $query->where('event_id', $session->event_id))
            ->where('active', true)
            ->firstOrFail();
    }

    /**
     * Simpan foto yang diunggah kiosk sebagai berkas.
     *
     * Hanya menerima berkas gambar sungguhan. Jalur lama yang menerima
     * `file_url` berupa string dari klien dihapus: string itu dipakai apa
     * adanya sebagai path berkas oleh portal unduhan, sehingga bisa dipakai
     * membaca berkas server mana pun.
     */
    protected function storeUploadedPhotos(Request $request, Session $sessionModel): void
    {
        $request->validate([
            'photos'        => ['nullable', 'array', 'max:12'],
            'photos.*'      => ['file', 'image', 'mimes:jpg,jpeg,png', 'max:12288'],
            'photo_files'   => ['nullable', 'array', 'max:12'],
            'photo_files.*' => ['file', 'image', 'mimes:jpg,jpeg,png', 'max:12288'],
        ]);

        $files = [];
        if ($request->hasFile('photos')) {
            $files = $request->file('photos');
        } elseif ($request->hasFile('photo_files')) {
            $files = $request->file('photo_files');
        }

        if (!is_array($files)) {
            $files = [$files];
        }

        foreach ($files as $file) {
            $path = $file->store('photos', 'public');
            Photo::create([
                'session_id' => $sessionModel->id,
                'file_url'   => $path,
                'type'       => 'raw',
            ]);
        }
    }

    /**
     * Mulai sesi untuk pembayaran yang SUDAH lunas.
     *
     * Sesi itu sendiri dibuat oleh PaymentController::store(); endpoint ini
     * hanya menyalakan timernya. Sebelumnya method ini membuat sesi aktif
     * sekaligus mengarang Payment Rp 48.000 berstatus 'paid' tanpa memeriksa
     * apa pun, sehingga satu request menghasilkan sesi gratis dan omset fiktif.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'payment_id' => ['required', 'integer', 'exists:payments,id'],
            'frame_id'   => ['nullable', 'integer', 'exists:frames,id'],
        ]);

        $payment = Payment::with('session')->findOrFail($request->payment_id);

        abort_if(
            $payment->status !== 'paid',
            402,
            'Pembayaran belum lunas.'
        );

        $session = $payment->session;
        abort_if(!$session, 404, 'Sesi untuk pembayaran ini tidak ditemukan.');

        $durationSeconds = $this->sessionDuration($session->event_id, $session->cafe_id);

        // Idempoten: kalau timer sudah menyala, jangan diulang dari awal.
        if ($session->status === 'pending' || !$session->started_at) {
            $session->update([
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => now()->addSeconds($durationSeconds),
            ]);
        }

        if ($request->filled('frame_id')) {
            $this->frameForSession((int) $request->frame_id, $session);
            $session->update(['frame_id' => $request->frame_id]);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'session_id'              => $session->id,
                'event_id'                => $session->event_id,
                'session_timeout_seconds' => $durationSeconds,
                'started_at'              => $session->started_at,
                'expires_at'              => $session->expires_at,
            ],
            'message' => 'Session dimulai.',
        ], 201);
    }

    /**
     * Simpan bingkai yang dipilih pelanggan.
     */
    public function setFrame(Request $request, $session): JsonResponse
    {
        $request->validate([
            'frame_id' => ['required', 'integer', 'exists:frames,id'],
        ]);

        $sessionModel = $this->resolvePaidSession($session);
        $this->frameForSession((int) $request->frame_id, $sessionModel);
        $sessionModel->update(['frame_id' => $request->frame_id]);

        return response()->json([
            'success' => true,
            'data'    => ['session_id' => $sessionModel->id],
            'message' => 'Frame disimpan.',
        ]);
    }

    /**
     * Unggah foto hasil pengambilan beserta filter yang dipilih.
     */
    public function uploadPhotos(Request $request, $session): JsonResponse
    {
        $sessionModel = $this->resolvePaidSession($session);

        $request->validate([
            'filter_id'       => ['nullable', 'integer', 'exists:filters,id'],
            'selected_filter' => ['nullable', 'string', 'max:100'],
        ]);

        if ($request->filled('filter_id')) {
            $sessionModel->update([
                'filter_id'       => $request->filter_id,
                'selected_filter' => $request->selected_filter,
            ]);
        }

        $this->storeUploadedPhotos($request, $sessionModel);

        $sessionModel->update(['status' => 'processing']);

        return response()->json([
            'success' => true,
            'data'    => ['session_id' => $sessionModel->id],
            'message' => 'Foto disimpan.',
        ]);
    }

    /**
     * Hasilkan Photo Strip HD, GIF animasi, dan tautan unduhan ber-QR (7 hari).
     */
    public function generateResult(Request $request, $session, \App\Services\GenerateResultService $generator): JsonResponse
    {
        $sessionModel = $this->resolvePaidSession($session);

        $request->validate([
            'filter_id'       => ['nullable', 'integer', 'exists:filters,id'],
            'selected_filter' => ['nullable', 'string', 'max:100'],
            'frame_id'        => ['nullable', 'integer', 'exists:frames,id'],
        ]);

        if ($request->filled('filter_id')) {
            $sessionModel->update([
                'filter_id'       => $request->filter_id,
                'selected_filter' => $request->selected_filter,
            ]);
        }

        if ($request->filled('frame_id')) {
            $this->frameForSession((int) $request->frame_id, $sessionModel);
            $sessionModel->update(['frame_id' => $request->frame_id]);
        }

        $this->storeUploadedPhotos($request, $sessionModel);

        $result = $generator->generate($sessionModel);

        $sessionModel->update(['status' => 'result_ready']);

        // Antrean cetak dicatat sebagai 'pending'. Sebelumnya langsung ditandai
        // 'done' dengan printed_at terisi, padahal belum ada pencetakan apa pun,
        // sehingga riwayat cetak di panel admin tidak mencerminkan kenyataan.
        \App\Models\PrintJob::firstOrCreate(
            ['session_id' => $sessionModel->id],
            [
                'printer' => 'Kiosk Thermal/Photo Printer',
                'status'  => 'pending',
            ]
        );

        $host = request()->getSchemeAndHttpHost();
        $downloadUrl = $host . '/d/' . $result->qr_token;

        return response()->json([
            'success' => true,
            'data'    => [
                'session_id'   => $sessionModel->id,
                'qr_token'     => $result->qr_token,
                'final_url'    => $result->final_url ? asset('storage/' . $result->final_url) : null,
                'gif_url'      => $result->gif_url ? asset('storage/' . $result->gif_url) : null,
                'download_url' => $downloadUrl,
                'expires_at'   => $result->expires_at,
            ],
            'message' => 'Hasil foto berhasil digenerate.',
        ]);
    }

    /**
     * Tutup sesi saat pelanggan menekan Selesai.
     */
    public function finish(Request $request, $session): JsonResponse
    {
        $sessionModel = $this->resolvePaidSession($session);

        $sessionModel->update([
            'status'      => 'finished',
            'finished_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data'    => ['status' => 'finished'],
            'message' => 'Sesi selesai.',
        ]);
    }
}
