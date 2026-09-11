<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cafe;
use App\Models\Device;
use App\Models\Event;
use App\Models\Payment;
use App\Models\Session;
use App\Services\PakasirService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    /** Harga sesi bawaan kalau cafe belum menyetel apa pun. */
    protected const DEFAULT_SESSION_PRICE = 25000;

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'event_id'       => ['nullable', 'exists:events,id'],
            'device_key'     => ['required', 'string'],
            'installation_id'=> ['required', 'uuid'],
        ]);

        // Tenant pembayaran selalu berasal dari pasangan perangkat yang telah
        // diaktivasi. Jangan percaya cafe_id/device_id mentah dari aplikasi.
        $device = Device::query()
            ->where('device_key', trim($request->device_key))
            ->where('installation_id', strtolower($request->installation_id))
            ->where('status', 'active')
            ->first();

        abort_if(!$device, 403, 'Perangkat belum aktif atau identitas instalasi tidak cocok.');

        $event = $request->event_id ? Event::find($request->event_id) : ($device?->event);

        abort_if($event && (int) $event->cafe_id !== (int) $device->cafe_id, 422, 'Event bukan milik cafe perangkat ini.');

        // Tenant harus bisa disimpulkan. Fallback lama ke Cafe::first() diam-diam
        // mengatribusikan pembayaran ke cafe pertama di tabel.
        $cafeId = $device->cafe_id;
        $cafe = $cafeId ? Cafe::find($cafeId) : null;

        abort_if(
            !$cafe,
            422,
            'Cafe tidak dapat ditentukan dari device / event yang dikirim.'
        );

        abort_if(
            !$cafe->isSubscriptionActive(),
            403,
            'Lisensi cafe ini sedang nonaktif atau kedaluwarsa.'
        );

        // Harga ditentukan server, bukan oleh perangkat di lapangan.
        // Sebelumnya `amount` diterima mentah dari body request dengan `min:0`,
        // sehingga kiosk yang dimodifikasi bisa membayar Rp 0.
        $amount = (int) ($cafe->session_price ?: self::DEFAULT_SESSION_PRICE);

        abort_if($amount < 1, 422, 'Harga sesi untuk cafe ini belum dikonfigurasi.');

        // 1. Buat sesi berstatus pending
        $session = Session::create([
            'cafe_id'   => $cafe->id,
            'event_id'  => $event?->id,
            'device_id' => $device?->id,
            'status'    => 'pending',
        ]);

        // 2. Buat record pembayaran
        $payment = Payment::create([
            'session_id'        => $session->id,
            'amount'            => $amount,
            'status'            => 'pending',
            'xendit_payment_id' => null,
        ]);

        // 3. Terbitkan Dynamic QRIS lewat Pakasir
        $qrisData = PakasirService::createQris($payment);

        // Kalau gateway tidak bisa menerbitkan QRIS, jangan pernah mengarang QR.
        if (!$qrisData) {
            $payment->update(['status' => 'failed']);
            $session->update(['status' => 'timeout']);

            return response()->json([
                'success' => false,
                'message' => 'Pembayaran tidak dapat diproses saat ini. Silakan hubungi kasir.',
            ], 503);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'payment_id'    => $payment->id,
                'session_id'    => $session->id,
                'order_id'      => $qrisData['order_id'],
                'external_id'   => $qrisData['order_id'],
                'amount'        => (int) $payment->amount,
                'total_payment' => $qrisData['total_payment'],
                'fee'           => $qrisData['fee'],
                'status'        => $payment->status,
                'qr_string'     => $qrisData['qr_string'],
                'expired_at'    => $qrisData['expired_at'],
            ],
            'message' => 'Dynamic QRIS Pakasir berhasil dibuat.',
        ], 201);
    }

    public function status(Request $request, Payment $payment): JsonResponse
    {
        $request->validate([
            'device_key' => ['required', 'string'],
            'installation_id' => ['required', 'uuid'],
        ]);
        $device = Device::query()
            ->where('device_key', trim($request->device_key))
            ->where('installation_id', strtolower($request->installation_id))
            ->where('status', 'active')
            ->first();

        abort_if(!$device || (int) $payment->session?->device_id !== (int) $device->id, 403, 'Transaksi bukan milik perangkat ini.');

        // Jika masih pending, coba cek status transaksi langsung ke Pakasir API
        if ($payment->status === 'pending') {
            PakasirService::checkStatus($payment);
            $payment->refresh();
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'payment_id'     => $payment->id,
                'status'         => $payment->status,
                'session_id'     => $payment->session_id,
                'session_status' => $payment->session?->status,
                'paid_at'        => $payment->paid_at,
                'is_simulated'   => $payment->is_simulated,
            ],
            'message' => 'OK',
        ]);
    }

    /**
     * Simulasi pembayaran untuk pengembangan dan pengujian.
     *
     * Hanya tersedia jika Super Admin mengaktifkannya untuk cafe terkait dan
     * pemanggil membuktikan identitas instalasi perangkat pemilik transaksi.
     */
    public function simulatePaid(Request $request, Payment $payment): JsonResponse
    {
        $request->validate([
            'device_key' => ['required', 'string'],
            'installation_id' => ['required', 'uuid'],
        ]);

        $device = Device::query()
            ->where('device_key', trim($request->device_key))
            ->where('installation_id', strtolower($request->installation_id))
            ->where('status', 'active')
            ->first();
        $session = $payment->session;
        $cafe = $session?->cafe;

        abort_if(!$device || !$session || (int) $session->device_id !== (int) $device->id, 403, 'Transaksi bukan milik perangkat ini.');
        abort_if(!$cafe || (int) $cafe->id !== (int) $device->cafe_id, 403, 'Transaksi bukan milik cafe ini.');
        abort_if(!$cafe->payment_simulation_enabled, 403, 'Simulasi pembayaran dinonaktifkan oleh Super Admin.');
        abort_if($payment->status !== 'pending', 409, 'Transaksi ini tidak lagi menunggu pembayaran.');

        PakasirService::simulatePaid($payment);
        $payment->refresh();

        return response()->json([
            'success' => true,
            'message' => 'Pembayaran berhasil disimulasikan sebagai LUNAS!',
            'data'    => [
                'payment_id'     => $payment->id,
                'status'         => $payment->status,
                'session_id'     => $payment->session_id,
                'session_status' => $payment->session?->status,
                'is_simulated'   => true,
            ],
        ]);
    }
}
