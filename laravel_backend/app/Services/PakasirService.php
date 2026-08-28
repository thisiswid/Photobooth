<?php

namespace App\Services;

use App\Models\Payment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PakasirService
{
    protected static function getSlug(): string
    {
        return config('services.pakasir.slug', env('PAKASIR_SLUG', 'snaptechbooth'));
    }

    protected static function getApiKey(): string
    {
        return config('services.pakasir.api_key', env('PAKASIR_API_KEY', 'UNDovg8HAySBJSyOUiC3DcyNvwmkC8x1'));
    }

    /**
     * Buat Dynamic QRIS via Pakasir API.
     * POST https://app.pakasir.com/api/transactioncreate/qris
     */
    public static function createQris(Payment $payment): array
    {
        $slug = self::getSlug();
        $apiKey = self::getApiKey();
        $orderId = 'STB-' . $payment->id . '-' . time();
        $amount = (int) $payment->amount;

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
                'response' => $response->json(),
                'status'   => $response->status(),
            ]);

            if ($response->successful()) {
                $data = $response->json('payment') ?? $response->json();
                $qrString = $data['payment_number'] ?? null;

                if ($qrString) {
                    $payment->update([
                        'xendit_payment_id' => $orderId, // Digunakan sebagai identifier transaksi / order_id
                    ]);

                    return [
                        'order_id'      => $orderId,
                        'qr_string'     => $qrString,
                        'total_payment' => $data['total_payment'] ?? $amount,
                        'fee'           => $data['fee'] ?? 0,
                        'expired_at'    => $data['expired_at'] ?? now()->addMinutes(15)->toIso8601String(),
                        'is_mock'       => false,
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

        // Fallback Mock QRIS string jika offline/koneksi API terkendala
        $fallbackOrderId = 'MOCK-' . $payment->id . '-' . time();
        $mockQr = "00020101021226610016ID.CO.SHOPEE.WWW01189360091800216005230208216005230303UME51440014ID.CO.QRIS.WWW0215ID10243228429300303UME5204792953033605409" . $amount . ".005802ID5913SnapTechBooth6007Jakarta61051234562230519MOCK" . $payment->id . "6304A079";

        $payment->update([
            'xendit_payment_id' => $fallbackOrderId,
        ]);

        return [
            'order_id'      => $fallbackOrderId,
            'qr_string'     => $mockQr,
            'total_payment' => $amount,
            'fee'           => 0,
            'expired_at'    => now()->addMinutes(15)->toIso8601String(),
            'is_mock'       => true,
        ];
    }

    /**
     * Cek status transaksi langsung ke API Pakasir
     * GET https://app.pakasir.com/api/transactiondetail?project={slug}&amount={amount}&order_id={order_id}&api_key={api_key}
     */
    public static function checkStatus(Payment $payment): ?string
    {
        $orderId = $payment->xendit_payment_id;
        if (!$orderId || str_starts_with($orderId, 'MOCK-')) {
            return null;
        }

        $slug = self::getSlug();
        $apiKey = self::getApiKey();
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

                if ($status === 'completed' || $status === 'paid' || $status === 'success') {
                    $payment->update([
                        'status'  => 'paid',
                        'paid_at' => now(),
                    ]);

                    if ($payment->session) {
                        $payment->session->update([
                            'status'     => 'active',
                            'started_at' => now(),
                            'expires_at' => now()->addMinutes(5),
                        ]);
                    }

                    return 'paid';
                }
            }
        } catch (\Throwable $e) {
            Log::warning("Failed to check Pakasir status for Payment #{$payment->id}: " . $e->getMessage());
        }

        return null;
    }

    /**
     * Simulasi Pembayaran Lunas (Sandbox / Testing)
     */
    public static function simulatePaid(Payment $payment): void
    {
        $slug = self::getSlug();
        $apiKey = self::getApiKey();
        $orderId = $payment->xendit_payment_id ?? ('STB-' . $payment->id);
        $amount = (int) $payment->amount;

        // Coba hit API simulasi resmi Pakasir jika bukan mock lokal
        if (!str_starts_with($orderId, 'MOCK-')) {
            try {
                Http::timeout(5)->post('https://app.pakasir.com/api/paymentsimulation', [
                    'project'  => $slug,
                    'order_id' => $orderId,
                    'amount'   => $amount,
                    'api_key'  => $apiKey,
                ]);
            } catch (\Throwable $e) {
                Log::warning("Pakasir payment simulation API call exception: " . $e->getMessage());
            }
        }

        // Tandai lunas di database lokal
        $payment->update([
            'status'  => 'paid',
            'paid_at' => now(),
        ]);

        if ($payment->session) {
            $payment->session->update([
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => now()->addMinutes(5),
            ]);
        }
    }
}
