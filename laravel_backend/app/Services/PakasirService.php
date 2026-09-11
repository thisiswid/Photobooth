<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\TimerSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PakasirService
{
    protected static function getSlug(): ?string
    {
        return config('services.pakasir.slug');
    }

    /**
     * Kunci API Pakasir. Sebelumnya method ini punya kunci asli sebagai nilai
     * default di dalam kode, sehingga kunci itu ikut ter-commit ke repo dan
     * tetap terpakai walau .env tidak mengisinya. Sekarang tanpa default:
     * kalau belum dikonfigurasi, penerbitan QRIS gagal dengan jelas.
     */
    protected static function getApiKey(): ?string
    {
        return config('services.pakasir.api_key');
    }

    /**
     * Tandai pembayaran lunas dan nyalakan timer sesinya.
     */
    protected static function markPaid(Payment $payment, bool $isSimulated = false): void
    {
        $payment->update([
            'status'  => 'paid',
            'paid_at' => now(),
            'is_simulated' => $isSimulated,
        ]);

        if ($payment->session) {
            $timerSetting = TimerSetting::resolveForCafe($payment->session->cafe_id);
            $duration = $timerSetting->session_timeout_seconds ?? 300;
            $payment->session->update([
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => now()->addSeconds($duration),
            ]);
        }
    }

    /**
     * Terbitkan Dynamic QRIS via Pakasir API.
     * POST https://app.pakasir.com/api/transactioncreate/qris
     *
     * Mengembalikan null kalau QRIS tidak bisa diterbitkan. Sebelumnya method
     * ini mengarang string QRIS merchant Shopee yang di-hardcode dan
     * mengirimkannya ke kiosk seolah-olah sah, sehingga tamu bisa diminta
     * memindai alat pembayaran milik pihak lain.
     */
    public static function createQris(Payment $payment): ?array
    {
        $slug = self::getSlug();
        $apiKey = self::getApiKey();

        if (empty($slug) || empty($apiKey)) {
            Log::error('Pakasir belum dikonfigurasi: PAKASIR_SLUG / PAKASIR_API_KEY kosong.');
            return null;
        }

        $orderId = 'STB-' . $payment->id . '-' . time();
        $amount = (int) $payment->amount;

        // Simpan order_id lebih dulu supaya webhook tetap bisa mencocokkan
        // pembayaran ini walau response API hilang di tengah jalan.
        $payment->update(['xendit_payment_id' => $orderId]);

        try {
            $response = Http::timeout(10)->post('https://app.pakasir.com/api/transactioncreate/qris', [
                'project'  => $slug,
                'order_id' => $orderId,
                'amount'   => $amount,
                'api_key'  => $apiKey,
            ]);

            Log::info("Pakasir QRIS Create Request for Payment #{$payment->id}", [
                'order_id' => $orderId,
                'amount'   => $amount,
                'status'   => $response->status(),
            ]);

            if ($response->successful()) {
                $data = $response->json('payment') ?? $response->json();
                $qrString = $data['payment_number'] ?? null;

                if ($qrString) {
                    return [
                        'order_id'      => $orderId,
                        'qr_string'     => $qrString,
                        'total_payment' => $data['total_payment'] ?? $amount,
                        'fee'           => $data['fee'] ?? 0,
                        'expired_at'    => $data['expired_at'] ?? now()->addMinutes(15)->toIso8601String(),
                    ];
                }
            }

            Log::warning("Pakasir QRIS API returned unhandled response for Payment #{$payment->id}", [
                'status' => $response->status(),
                'body'   => $response->body(),
            ]);
        } catch (\Throwable $e) {
            Log::error("Pakasir QRIS API Exception for Payment #{$payment->id}: " . $e->getMessage());
        }

        return null;
    }

    /**
     * Cek status transaksi langsung ke API Pakasir.
     * GET https://app.pakasir.com/api/transactiondetail
     */
    public static function checkStatus(Payment $payment): ?string
    {
        $orderId = $payment->xendit_payment_id;
        $slug = self::getSlug();
        $apiKey = self::getApiKey();

        if (!$orderId || empty($slug) || empty($apiKey)) {
            return null;
        }

        $amount = (int) $payment->amount;

        try {
            $response = Http::timeout(8)->get('https://app.pakasir.com/api/transactiondetail', [
                'project'  => $slug,
                'amount'   => $amount,
                'order_id' => $orderId,
                'api_key'  => $apiKey,
            ]);

            if ($response->successful()) {
                $transaction = $response->json('transaction') ?? $response->json();
                $status = strtolower($transaction['status'] ?? '');

                // Nominal yang dilaporkan gateway harus sama dengan yang ditagih.
                $reportedAmount = (int) ($transaction['amount'] ?? $amount);
                if ($reportedAmount !== $amount) {
                    Log::warning("Pakasir amount mismatch for Payment #{$payment->id}: expected {$amount}, got {$reportedAmount}");
                    return null;
                }

                if (in_array($status, ['completed', 'paid', 'success'], true)) {
                    self::markPaid($payment);
                    return 'paid';
                }
            }
        } catch (\Throwable $e) {
            Log::warning("Failed to check Pakasir status for Payment #{$payment->id}: " . $e->getMessage());
        }

        return null;
    }

    /**
     * Simulasi pembayaran lunas untuk pengembangan dan pengujian.
     * Transaksi simulasi hanya dicatat secara lokal dan tidak dikirim ke
     * gateway Pakasir agar tidak tercampur dengan dana pembayaran sebenarnya.
     */
    public static function simulatePaid(Payment $payment): void
    {
        self::markPaid($payment, true);
    }
}
