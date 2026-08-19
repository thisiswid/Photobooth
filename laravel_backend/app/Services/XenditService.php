<?php

namespace App\Services;

use App\Models\Payment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class XenditService
{
    /**
     * Membuat Dynamic QRIS melalui API Xendit.
     * Jika API key belum diisi, otomatis fallback ke Mock QR untuk testing lokal.
     */
    public static function createQris(Payment $payment): array
    {
        $secretKey = config('services.xendit.secret_key');
        $externalId = 'PB-PAY-' . $payment->id . '-' . time();

        // 1. Fallback Mock Testing jika API Key belum dipasang
        if (empty($secretKey)) {
            $payment->update([
                'xendit_payment_id' => $externalId,
            ]);

            return [
                'external_id' => $externalId,
                'qr_string'   => '00020101021226580014ID.LINKAJA.WWW01189360091100000000000215' . Str::random(20) . '5802ID5914Fakultas Kopi6005Depok62070703A016304' . strtoupper(Str::random(4)),
                'status'      => 'PENDING',
                'is_mock'     => true,
            ];
        }

        // 2. Real Xendit API Call (Sandbox / Production)
        try {
            $response = Http::withBasicAuth($secretKey, '')
                ->post('https://api.xendit.co/qr_codes', [
                    'external_id'  => $externalId,
                    'type'         => 'DYNAMIC',
                    'currency'     => 'IDR',
                    'amount'       => (int) $payment->amount,
                    'expires_at'   => now()->addMinutes(5)->toIso8601String(),
                ]);

            if ($response->successful()) {
                $data = $response->json();
                $payment->update([
                    'xendit_payment_id' => $data['external_id'] ?? $externalId,
                ]);

                return [
                    'external_id' => $data['external_id'] ?? $externalId,
                    'qr_string'   => $data['qr_string'] ?? '',
                    'status'      => $data['status'] ?? 'PENDING',
                    'is_mock'     => false,
                ];
            }

            Log::error('Xendit QR Code creation failed', [
                'status'   => $response->status(),
                'response' => $response->json(),
            ]);
        } catch (\Throwable $e) {
            Log::error('Xendit API Exception: ' . $e->getMessage());
        }

        // Fallback jika API Xendit gagal
        $payment->update(['xendit_payment_id' => $externalId]);

        return [
            'external_id' => $externalId,
            'qr_string'   => 'XENDIT_QRIS_FALLBACK_' . $payment->id,
            'status'      => 'PENDING',
            'is_mock'     => true,
        ];
    }

    /**
     * Simulasi Pembayaran Sukses (Khusus Testing / Manual Kasir).
     */
    public static function simulatePaid(Payment $payment): bool
    {
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

        return true;
    }
}
