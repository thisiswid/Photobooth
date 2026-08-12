<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Session;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'event_id' => ['required', 'exists:events,id'],
            'amount'   => ['required', 'numeric', 'min:0'],
        ]);

        // Create pending session
        $session = Session::create([
            'event_id' => $request->event_id,
            'status'   => 'pending',
        ]);

        // Create payment record
        $payment = Payment::create([
            'session_id'         => $session->id,
            'amount'             => $request->amount,
            'status'             => 'pending',
            'xendit_payment_id'  => null,
        ]);

        // TODO: integrate real Xendit QRIS creation here
        // $xendit = XenditService::createQris($payment);

        return response()->json([
            'success' => true,
            'data'    => [
                'payment_id' => $payment->id,
                'session_id' => $session->id,
                'amount'     => $payment->amount,
                'status'     => $payment->status,
                'qr_string'  => 'XENDIT_QRIS_PLACEHOLDER',
            ],
            'message' => 'Payment dibuat.',
        ], 201);
    }

    public function status(Payment $payment): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => [
                'payment_id' => $payment->id,
                'status'     => $payment->status,
                'paid_at'    => $payment->paid_at,
            ],
            'message' => 'OK',
        ]);
    }
}
