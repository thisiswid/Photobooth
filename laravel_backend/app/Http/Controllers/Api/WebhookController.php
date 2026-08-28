<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class WebhookController extends Controller
{
    public function xendit(Request $request): JsonResponse
    {
        $token = $request->header('x-callback-token');
        $expectedToken = config('services.xendit.webhook_token');

        // Verify token if configured in .env
        if (!empty($expectedToken) && $token !== $expectedToken) {
            Log::warning('Invalid Xendit webhook token received', [
                'received' => $token,
            ]);
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $data = $request->all();
        Log::info('Xendit webhook received', $data);

        // Ekstraksi External ID dari berbagai format payload Xendit (QRIS, Invoice, VA, Test)
        $externalId = $data['qr_code']['external_id'] 
            ?? $data['external_id'] 
            ?? $data['reference_id'] 
            ?? $data['data']['qr_code']['external_id'] 
            ?? $data['data']['reference_id'] 
            ?? null;

        $status = strtoupper($data['status'] ?? $data['event'] ?? 'PAID');

        // Jika ini adalah Test Webhook dari tombol "Test Webhook" di dashboard Xendit
        if (!$externalId && isset($data['event'])) {
            return response()->json(['message' => 'Test Webhook Verified successfully', 'status' => 'OK']);
        }

        if (!$externalId) {
            return response()->json(['message' => 'Webhook received, but external_id not found in payload', 'payload' => $data], 200);
        }

        $payment = Payment::where('xendit_payment_id', $externalId)->first();

        // Fallback: jika payment ID diekstrak dari format 'PB-PAY-{id}-...'
        if (!$payment && preg_match('/PB-PAY-(\d+)/', $externalId, $matches)) {
            $payment = Payment::find($matches[1]);
        }

        if (!$payment) {
            Log::warning('Payment record not found for external_id: ' . $externalId);
            return response()->json(['message' => 'Payment not found in local database, but webhook acknowledged'], 200);
        }

        if (in_array($status, ['PAID', 'SETTLED', 'COMPLETED', 'QR.PAYMENT'])) {
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

            Log::info("Payment #{$payment->id} and Session #{$payment->session_id} successfully ACTIVATED via Xendit Webhook.");
        } elseif (in_array($status, ['EXPIRED', 'FAILED'])) {
            $payment->update(['status' => 'failed']);
        }

        return response()->json([
            'message'    => 'OK',
            'payment_id' => $payment->id,
            'status'     => $payment->status,
        ]);
    }

    /**
     * Webhook Receiver untuk Pakasir.
     * URL: https://snaptechbooth.my.id/api/webhooks/pakasir
     * Payload: { "amount": 25000, "order_id": "STB-...", "project": "snaptechbooth", "status": "completed", "payment_method": "qris", ... }
     */
    public function pakasir(Request $request): JsonResponse
    {
        $data = $request->all();
        Log::info('Pakasir webhook received', $data);

        $orderId = $data['order_id'] ?? null;
        $status = strtolower($data['status'] ?? '');
        $amount = (int) ($data['amount'] ?? 0);
        $project = $data['project'] ?? '';

        $expectedSlug = config('services.pakasir.slug', 'snaptechbooth');
        if (!empty($project) && $project !== $expectedSlug) {
            Log::warning("Pakasir webhook project slug mismatch: expected {$expectedSlug}, got {$project}");
        }

        if (!$orderId) {
            return response()->json(['message' => 'Missing order_id'], 400);
        }

        $payment = Payment::where('xendit_payment_id', $orderId)->first();

        // Fallback: parse ID from format 'STB-{id}-...'
        if (!$payment && preg_match('/STB-(\d+)/', $orderId, $matches)) {
            $payment = Payment::find($matches[1]);
        }

        if (!$payment) {
            Log::warning('Pakasir webhook payment record not found for order_id: ' . $orderId);
            return response()->json(['message' => 'Payment not found in local database'], 200);
        }

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

            Log::info("Payment #{$payment->id} and Session #{$payment->session_id} successfully ACTIVATED via Pakasir Webhook.");
        } elseif ($status === 'failed' || $status === 'expired' || $status === 'cancelled') {
            $payment->update(['status' => 'failed']);
        }

        return response()->json([
            'message'    => 'Webhook processed successfully',
            'payment_id' => $payment->id,
            'status'     => $payment->status,
        ]);
    }
}
