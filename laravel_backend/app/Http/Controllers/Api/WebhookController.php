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
        // Verify Xendit webhook token
        $token = $request->header('x-callback-token');
        if ($token !== config('services.xendit.webhook_token')) {
            Log::warning('Invalid Xendit webhook token');
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $data = $request->all();
        Log::info('Xendit webhook received', $data);

        $externalId = $data['external_id'] ?? null;
        $status     = $data['status'] ?? null;

        if (!$externalId || !$status) {
            return response()->json(['message' => 'Invalid payload'], 422);
        }

        $payment = Payment::where('xendit_payment_id', $externalId)->first();

        if (!$payment) {
            return response()->json(['message' => 'Payment not found'], 404);
        }

        if ($status === 'PAID' || $status === 'SETTLED') {
            $payment->update([
                'status'  => 'paid',
                'paid_at' => now(),
            ]);
            $payment->session->update(['status' => 'active']);
        } elseif ($status === 'EXPIRED' || $status === 'FAILED') {
            $payment->update(['status' => 'failed']);
        }

        return response()->json(['message' => 'OK']);
    }
}
