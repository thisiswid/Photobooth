<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhotoSession;
use App\Models\Package;
use App\Http\Requests\CreateSessionRequest;
use App\Http\Requests\UpdatePaymentRequest;
use App\Http\Resources\SessionResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionController extends Controller
{
    /**
     * Create a new photobooth session after payment selection.
     */
    public function create(CreateSessionRequest $request): JsonResponse
    {
        $package = Package::findOrFail($request->package_id);

        $session = PhotoSession::create([
            'session_code'   => PhotoSession::generateCode(),
            'payment_status' => 'pending',
            'package_id'     => $package->id,
            'started_at'     => now(),
            'expired_at'     => now()->addMinutes(config('photobooth.session_duration_minutes', 10)),
        ]);

        return response()->json([
            'success' => true,
            'data'    => [
                'session_code' => $session->session_code,
                'expires_at'   => $session->expired_at->toIso8601String(),
                'package'      => [
                    'id'          => $package->id,
                    'name'        => $package->name,
                    'photo_count' => $package->photo_count,
                    'print_count' => $package->print_count,
                    'price'       => $package->price,
                ],
            ],
            'message' => 'Sesi berhasil dibuat.',
        ], 201);
    }

    /**
     * Return session details with photos, package, frame, and layout.
     */
    public function show(string $code): JsonResponse
    {
        $session = PhotoSession::with(['photos', 'package', 'frame', 'layout'])
                               ->where('session_code', $code)
                               ->firstOrFail();

        return response()->json([
            'success' => true,
            'data'    => new SessionResource($session),
            'message' => 'OK',
        ]);
    }

    /**
     * Update the payment status for a session.
     */
    public function updatePayment(UpdatePaymentRequest $request, string $code): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)->firstOrFail();
        $session->update(['payment_status' => $request->payment_status]);

        return response()->json([
            'success' => true,
            'data'    => ['payment_status' => $session->payment_status],
            'message' => 'Status pembayaran diperbarui.',
        ]);
    }

    /**
     * Mark a session as completed.
     */
    public function finalize(string $code): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)->firstOrFail();
        $session->update([
            'completed_at' => now(),
            'total_photos' => $session->photos()->where('photo_type', 'individual')->count(),
        ]);

        return response()->json([
            'success' => true,
            'data'    => ['completed_at' => $session->completed_at->toIso8601String()],
            'message' => 'Sesi selesai.',
        ]);
    }
}
