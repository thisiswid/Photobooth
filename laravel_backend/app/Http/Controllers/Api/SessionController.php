<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Photo;
use App\Models\Session;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Handles session lifecycle for the Flutter customer app.
 *
 * Flow: POST /sessions → setFrame → uploadPhotos → finish
 * No email anywhere in this controller.
 */
class SessionController extends Controller
{
    /**
     * Create / start a session after payment is confirmed PAID.
     * Sets status=active and starts the 5-minute timer.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'payment_id' => ['required', 'exists:payments,id'],
        ]);

        $payment = \App\Models\Payment::where('id', $request->payment_id)
            ->where('status', 'paid')
            ->firstOrFail();

        $session = $payment->session;
        $session->update([
            'status'     => 'active',
            'started_at' => now(),
            'expires_at' => now()->addMinutes(5),
        ]);

        return response()->json([
            'success' => true,
            'data'    => [
                'session_id' => $session->id,
                'started_at' => $session->started_at,
                'expires_at' => $session->expires_at,
            ],
            'message' => 'Session dimulai.',
        ], 201);
    }

    /**
     * Save the frame selected by the customer.
     * Must be called before entering Photo Session (business rule #5).
     */
    public function setFrame(Request $request, Session $session): JsonResponse
    {
        $request->validate([
            'frame_id' => ['required', 'exists:frames,id'],
        ]);

        $session->update(['frame_id' => $request->frame_id]);

        return response()->json([
            'success' => true,
            'data'    => null,
            'message' => 'Frame disimpan.',
        ]);
    }

    /**
     * Upload captured photos with the selected filter.
     * Transitions session status to processing.
     */
    public function uploadPhotos(Request $request, Session $session): JsonResponse
    {
        $request->validate([
            'filter_id'       => ['nullable', 'exists:filters,id'],
            'selected_filter' => ['nullable', 'string'],
            'photos'          => ['required', 'array', 'min:1'],
            'photos.*.url'    => ['required', 'string'],
            'photos.*.type'   => ['nullable', 'string', 'in:raw,final'],
        ]);

        if ($request->filled('filter_id')) {
            $session->update([
                'filter_id'       => $request->filter_id,
                'selected_filter' => $request->selected_filter,
            ]);
        }

        foreach ($request->photos as $photo) {
            Photo::create([
                'session_id' => $session->id,
                'file_url'   => $photo['url'],
                'type'       => $photo['type'] ?? 'raw',
            ]);
        }

        $session->update(['status' => 'processing']);

        return response()->json([
            'success' => true,
            'data'    => null,
            'message' => 'Foto disimpan.',
        ]);
    }

    /**
     * Finish the session when customer presses Selesai.
     * Returns to Welcome Screen flow. No email.
     */
    public function finish(Request $request, Session $session): JsonResponse
    {
        $session->update([
            'status'      => 'finished',
            'finished_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data'    => ['status' => 'finished'],
            'message' => 'Sesi selesai.',
        ]);
    }
}
