<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Payment;
use App\Models\Session;
use App\Services\XenditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'event_id'  => ['nullable', 'exists:events,id'],
            'device_id' => ['nullable', 'exists:devices,id'],
            'amount'    => ['required', 'numeric', 'min:0'],
        ]);

        $event = $request->event_id ? Event::find($request->event_id) : null;
        $cafeId = $event?->cafe_id ?? auth()->user()?->cafe_id;

        // 1. Create pending session
        $session = Session::create([
            'cafe_id'   => $cafeId,
            'event_id'  => $request->event_id,
            'device_id' => $request->device_id,
            'status'    => 'pending',
        ]);

        // 2. Create payment record
        $payment = Payment::create([
            'session_id'        => $session->id,
            'amount'            => $request->amount,
            'status'            => 'pending',
            'xendit_payment_id' => null,
        ]);

        // 3. Generate Dynamic QRIS via Xendit / Mock
        $qrisData = XenditService::createQris($payment);

        return response()->json([
            'success' => true,
            'data'    => [
                'payment_id'  => $payment->id,
                'session_id'  => $session->id,
                'external_id' => $qrisData['external_id'],
                'amount'      => $payment->amount,
                'status'      => $payment->status,
                'qr_string'   => $qrisData['qr_string'],
                'is_mock'     => $qrisData['is_mock'],
            ],
            'message' => 'Dynamic QRIS berhasil dibuat.',
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

    /**
     * Endpoint untuk simulasi bayar / manual cash kasir saat testing.
     */
    public function simulatePaid(Payment $payment): JsonResponse
    {
        XenditService::simulatePaid($payment);

        return response()->json([
            'success' => true,
            'message' => 'Pembayaran berhasil disimulasikan sebagai LUNAS!',
            'data'    => [
                'payment_id'     => $payment->id,
                'status'         => $payment->status,
                'session_id'     => $payment->session_id,
                'session_status' => $payment->session?->status,
            ],
        ]);
    }
}
