<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cafe;
use App\Models\Device;
use App\Models\Event;
use App\Models\Payment;
use App\Models\Session;
use App\Services\PakasirService;
use App\Services\VoucherService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    /** Harga sesi bawaan kalau cafe belum menyetel apa pun. */
    protected const DEFAULT_SESSION_PRICE = 25000;

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'event_id' => ['nullable', 'exists:events,id'],
            'device_key' => ['required', 'string'],
            'installation_id' => ['required', 'uuid'],
            'voucher_code' => ['nullable', 'string', 'max:64'],
        ]);

        $installationId = strtolower($request->installation_id);

        // Tenant pembayaran selalu berasal dari pasangan perangkat yang telah
        // diaktivasi. Jangan percaya cafe_id/device_id mentah dari aplikasi.
        $device = Device::query()
            ->where('device_key', trim($request->device_key))
            ->where('installation_id', $installationId)
            ->where('status', 'active')
            ->first();

        abort_if(! $device, 403, 'Perangkat belum aktif atau identitas instalasi tidak cocok.');

        $event = $request->event_id ? Event::find($request->event_id) : ($device?->event);

        abort_if($event && (int) $event->cafe_id !== (int) $device->cafe_id, 422, 'Event bukan milik cafe perangkat ini.');

        // Tenant harus bisa disimpulkan. Fallback lama ke Cafe::first() diam-diam
        // mengatribusikan pembayaran ke cafe pertama di tabel.
        $cafeId = $device->cafe_id;
        $cafe = $cafeId ? Cafe::find($cafeId) : null;

        abort_if(
            ! $cafe,
            422,
            'Cafe tidak dapat ditentukan dari device / event yang dikirim.'
        );

        abort_if(
            ! $cafe->isSubscriptionActive(),
            403,
            'Lisensi cafe ini sedang nonaktif atau kedaluwarsa.'
        );

        // Harga ditentukan server, bukan oleh perangkat di lapangan.
        // Sebelumnya `amount` diterima mentah dari body request dengan `min:0`,
        // sehingga kiosk yang dimodifikasi bisa membayar Rp 0.
        $amount = (int) ($cafe->session_price ?: self::DEFAULT_SESSION_PRICE);

        abort_if($amount < 1, 422, 'Harga sesi untuk cafe ini belum dikonfigurasi.');

        $voucherCode = trim((string) $request->voucher_code);

        [$session, $payment] = DB::transaction(function () use ($cafe, $event, $device, $amount, $voucherCode, $installationId) {
            $quote = $voucherCode !== ''
                ? VoucherService::quote($cafe, $voucherCode, $amount, $event?->id, $installationId, true)
                : null;
            $finalAmount = $quote['final_amount'] ?? $amount;

            $session = Session::create([
                'cafe_id' => $cafe->id,
                'event_id' => $event?->id,
                'device_id' => $device->id,
                'status' => 'pending',
            ]);

            $payment = Payment::create([
                'session_id' => $session->id,
                'voucher_id' => $quote['voucher']->id ?? null,
                'original_amount' => $amount,
                'discount_amount' => $quote['discount_amount'] ?? 0,
                'amount' => $finalAmount,
                'payment_method' => $finalAmount === 0 ? 'voucher' : ($quote ? 'qris_voucher' : 'qris'),
                'status' => 'pending',
                'xendit_payment_id' => null,
            ]);

            if ($quote) {
                VoucherService::reserve($quote, $device, $session, $payment, $installationId);
            }

            return [$session, $payment];
        });

        if ((int) $payment->amount === 0) {
            PakasirService::markPaid($payment);

            return response()->json([
                'success' => true,
                'data' => $this->paymentResponseData($payment->fresh(), null),
                'message' => 'Voucher gratis berhasil digunakan. Sesi foto langsung aktif.',
            ], 201);
        }

        // 3. Terbitkan Dynamic QRIS lewat Pakasir
        $qrisData = PakasirService::createQris($payment);

        // Kalau gateway tidak bisa menerbitkan QRIS, jangan pernah mengarang QR.
        if (! $qrisData) {
            $payment->update(['status' => 'failed']);
            $session->update(['status' => 'timeout']);
            VoucherService::release($payment);

            return response()->json([
                'success' => false,
                'message' => 'Pembayaran tidak dapat diproses saat ini. Silakan hubungi kasir.',
            ], 503);
        }

        return response()->json([
            'success' => true,
            'data' => $this->paymentResponseData($payment, $qrisData),
            'message' => 'Dynamic QRIS Pakasir berhasil dibuat.',
        ], 201);
    }

    public function validateVoucher(Request $request): JsonResponse
    {
        $request->validate([
            'device_key' => ['required', 'string'],
            'installation_id' => ['required', 'uuid'],
            'event_id' => ['nullable', 'exists:events,id'],
            'voucher_code' => ['required', 'string', 'max:64'],
        ]);

        $device = Device::query()
            ->where('device_key', trim($request->device_key))
            ->where('installation_id', strtolower($request->installation_id))
            ->where('status', 'active')
            ->with('cafe')
            ->first();
        abort_if(! $device?->cafe, 403, 'Perangkat belum aktif atau identitas instalasi tidak cocok.');

        $eventId = $request->integer('event_id') ?: null;
        if ($eventId) {
            abort_if(! Event::whereKey($eventId)->where('cafe_id', $device->cafe_id)->exists(), 422, 'Event bukan milik cafe perangkat ini.');
        }

        $amount = (int) ($device->cafe->session_price ?: self::DEFAULT_SESSION_PRICE);
        $quote = VoucherService::quote(
            $device->cafe,
            $request->voucher_code,
            $amount,
            $eventId,
            strtolower($request->installation_id),
        );

        return response()->json([
            'success' => true,
            'message' => 'Voucher dapat digunakan.',
            'data' => [
                'code' => $quote['voucher']->code,
                'name' => $quote['voucher']->name,
                'type' => $quote['voucher']->type,
                'original_amount' => $quote['original_amount'],
                'discount_amount' => $quote['discount_amount'],
                'final_amount' => $quote['final_amount'],
            ],
        ]);
    }

    private function paymentResponseData(Payment $payment, ?array $qrisData): array
    {
        return [
            'payment_id' => $payment->id,
            'session_id' => $payment->session_id,
            'order_id' => $qrisData['order_id'] ?? null,
            'external_id' => $qrisData['order_id'] ?? null,
            'original_amount' => (int) $payment->original_amount,
            'discount_amount' => (int) $payment->discount_amount,
            'amount' => (int) $payment->amount,
            'total_payment' => (int) ($qrisData['total_payment'] ?? $payment->amount),
            'fee' => (int) ($qrisData['fee'] ?? 0),
            'status' => $payment->status,
            'payment_method' => $payment->payment_method,
            'voucher_code' => $payment->voucher?->code,
            'qr_string' => $qrisData['qr_string'] ?? null,
            'expired_at' => $qrisData['expired_at'] ?? null,
        ];
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

        abort_if(! $device || (int) $payment->session?->device_id !== (int) $device->id, 403, 'Transaksi bukan milik perangkat ini.');

        // Jika masih pending, coba cek status transaksi langsung ke Pakasir API
        if ($payment->status === 'pending') {
            PakasirService::checkStatus($payment);
            $payment->refresh();
        }

        return response()->json([
            'success' => true,
            'data' => [
                'payment_id' => $payment->id,
                'status' => $payment->status,
                'session_id' => $payment->session_id,
                'session_status' => $payment->session?->status,
                'paid_at' => $payment->paid_at,
                'is_simulated' => $payment->is_simulated,
                'original_amount' => (int) $payment->original_amount,
                'discount_amount' => (int) $payment->discount_amount,
                'payment_method' => $payment->payment_method,
                'voucher_code' => $payment->voucher?->code,
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

        abort_if(! $device || ! $session || (int) $session->device_id !== (int) $device->id, 403, 'Transaksi bukan milik perangkat ini.');
        abort_if(! $cafe || (int) $cafe->id !== (int) $device->cafe_id, 403, 'Transaksi bukan milik cafe ini.');
        abort_if(! $cafe->payment_simulation_enabled, 403, 'Simulasi pembayaran dinonaktifkan oleh Super Admin.');
        abort_if($payment->status !== 'pending', 409, 'Transaksi ini tidak lagi menunggu pembayaran.');

        PakasirService::simulatePaid($payment);
        $payment->refresh();

        return response()->json([
            'success' => true,
            'message' => 'Pembayaran berhasil disimulasikan sebagai LUNAS!',
            'data' => [
                'payment_id' => $payment->id,
                'status' => $payment->status,
                'session_id' => $payment->session_id,
                'session_status' => $payment->session?->status,
                'is_simulated' => true,
            ],
        ]);
    }
}
