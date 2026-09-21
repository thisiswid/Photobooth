<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\PaymentReconciliation;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PakasirReconciliationService
{
    public function reconcile(
        Payment $payment,
        string $source = 'manual',
        ?int $checkedBy = null,
        bool $recordHistory = true,
    ): ?PaymentReconciliation {
        $payment->loadMissing('session');
        $localStatus = $payment->status;
        $expectedAmount = (int) $payment->amount;
        $checkedAt = now();

        if ($payment->is_simulated) {
            return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                'local_status_before' => $localStatus,
                'gateway_status' => null,
                'result' => 'not_applicable',
                'expected_amount' => $expectedAmount,
                'gateway_amount' => null,
                'message' => 'Dana simulasi tidak diperiksa ke Pakasir.',
                'response_payload' => null,
                'checked_at' => $checkedAt,
            ]);
        }

        $credentials = PakasirService::credentials();
        if (! $payment->xendit_payment_id || empty($credentials['slug']) || empty($credentials['api_key'])) {
            return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                'local_status_before' => $localStatus,
                'gateway_status' => null,
                'result' => 'error',
                'expected_amount' => $expectedAmount,
                'gateway_amount' => null,
                'message' => 'Order ID atau kredensial Pakasir belum tersedia.',
                'response_payload' => null,
                'checked_at' => $checkedAt,
            ]);
        }

        try {
            $response = Http::timeout(10)->retry(2, 250)->get('https://app.pakasir.com/api/transactiondetail', [
                'project' => $credentials['slug'],
                'amount' => $expectedAmount,
                'order_id' => $payment->xendit_payment_id,
                'api_key' => $credentials['api_key'],
            ]);

            if (! $response->successful()) {
                return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                    'local_status_before' => $localStatus,
                    'gateway_status' => null,
                    'result' => 'error',
                    'expected_amount' => $expectedAmount,
                    'gateway_amount' => null,
                    'message' => 'Pakasir merespons HTTP '.$response->status().'.',
                    'response_payload' => ['http_status' => $response->status()],
                    'checked_at' => $checkedAt,
                ]);
            }

            $transaction = $response->json('transaction') ?? $response->json();
            $gatewayStatus = strtolower((string) ($transaction['status'] ?? 'unknown'));
            $gatewayAmount = (int) ($transaction['amount'] ?? $transaction['total_payment'] ?? $expectedAmount);
            $gatewayOrderId = (string) ($transaction['order_id'] ?? $payment->xendit_payment_id);

            if ($gatewayAmount !== $expectedAmount || $gatewayOrderId !== $payment->xendit_payment_id) {
                return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                    'local_status_before' => $localStatus,
                    'gateway_status' => $gatewayStatus,
                    'result' => 'mismatch',
                    'expected_amount' => $expectedAmount,
                    'gateway_amount' => $gatewayAmount,
                    'message' => 'Nominal atau Order ID dari gateway tidak cocok. Status lokal tidak diubah.',
                    'response_payload' => $transaction,
                    'checked_at' => $checkedAt,
                ]);
            }

            [$result, $message] = $this->synchronizeStatus($payment, $gatewayStatus, $localStatus);

            return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                'local_status_before' => $localStatus,
                'gateway_status' => $gatewayStatus,
                'result' => $result,
                'expected_amount' => $expectedAmount,
                'gateway_amount' => $gatewayAmount,
                'message' => $message,
                'response_payload' => $transaction,
                'checked_at' => $checkedAt,
            ]);
        } catch (\Throwable $exception) {
            Log::warning("Rekonsiliasi Pakasir gagal untuk Payment #{$payment->id}", [
                'message' => $exception->getMessage(),
            ]);

            return $this->finish($payment, $source, $checkedBy, $recordHistory, [
                'local_status_before' => $localStatus,
                'gateway_status' => null,
                'result' => 'error',
                'expected_amount' => $expectedAmount,
                'gateway_amount' => null,
                'message' => 'Tidak dapat menghubungi Pakasir: '.$exception->getMessage(),
                'response_payload' => null,
                'checked_at' => $checkedAt,
            ]);
        }
    }

    private function synchronizeStatus(Payment $payment, string $gatewayStatus, string $localStatus): array
    {
        if (in_array($gatewayStatus, ['completed', 'paid', 'success'], true)) {
            if ($localStatus !== 'paid') {
                PakasirService::markPaid($payment);

                return ['updated', 'Pembayaran lokal diperbarui menjadi lunas sesuai Pakasir.'];
            }

            return ['matched', 'Status pembayaran lokal sesuai dengan Pakasir.'];
        }

        if (in_array($gatewayStatus, ['failed', 'expired', 'cancelled', 'canceled'], true)) {
            if ($localStatus === 'paid') {
                return ['mismatch', 'Pakasir menyatakan gagal, tetapi transaksi lokal sudah lunas. Perlu pemeriksaan manual.'];
            }

            if ($localStatus !== 'failed') {
                $payment->update(['status' => 'failed']);
                $payment->session?->update(['status' => 'timeout']);
                VoucherService::release($payment);

                return ['updated', 'Pembayaran lokal ditutup karena transaksi Pakasir gagal atau kedaluwarsa.'];
            }

            return ['matched', 'Status gagal lokal sesuai dengan Pakasir.'];
        }

        if (in_array($gatewayStatus, ['pending', 'waiting', 'unpaid', 'processing'], true)) {
            if ($localStatus === 'pending') {
                return ['pending', 'Pembayaran masih menunggu penyelesaian di Pakasir.'];
            }

            return ['mismatch', 'Status lokal tidak cocok dengan status pending di Pakasir.'];
        }

        return ['error', 'Status Pakasir tidak dikenali: '.$gatewayStatus.'.'];
    }

    private function finish(
        Payment $payment,
        string $source,
        ?int $checkedBy,
        bool $recordHistory,
        array $result,
    ): ?PaymentReconciliation {
        $payment->update([
            'gateway_status' => $result['gateway_status'],
            'reconciliation_status' => $result['result'],
            'reconciliation_message' => $result['message'],
            'last_gateway_check_at' => $result['checked_at'],
        ]);

        if (! $recordHistory) {
            return null;
        }

        return PaymentReconciliation::create([
            'payment_id' => $payment->id,
            'cafe_id' => $payment->session?->cafe_id,
            'checked_by' => $checkedBy,
            'source' => $source,
            ...$result,
        ]);
    }
}
