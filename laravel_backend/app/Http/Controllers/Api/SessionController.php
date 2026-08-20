<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\Photo;
use App\Models\Session;
use App\Models\TimerSetting;
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
     * Sets status=active and starts the session timer dynamically from TimerSetting.
     */
    public function store(Request $request): JsonResponse
    {
        $eventId = (int)$request->input('event_id', 1);
        $frameId = $request->input('frame_id');

        $event = Event::find($eventId);
        $cafeId = $event?->cafe_id ?? \App\Models\Cafe::first()?->id;
        $timerSetting = TimerSetting::where('event_id', $eventId)->where('is_active', true)->first()
            ?? TimerSetting::resolveForCafe($cafeId);

        $durationSeconds = $timerSetting->session_timeout_seconds ?? 360;

        $session = Session::create([
            'cafe_id'    => $cafeId,
            'event_id'   => $eventId,
            'frame_id'   => $frameId,
            'status'     => 'active',
            'started_at' => now(),
            'expires_at' => now()->addSeconds($durationSeconds),
        ]);

        return response()->json([
            'success' => true,
            'data'    => [
                'session_id'              => $session->id,
                'event_id'                => $session->event_id,
                'session_timeout_seconds' => $durationSeconds,
                'started_at'              => $session->started_at,
                'expires_at'              => $session->expires_at,
            ],
            'message' => 'Session dimulai.',
        ], 201);
    }

    /**
     * Save the frame selected by the customer.
     * Must be called before entering Photo Session (business rule #5).
     */
    public function setFrame(Request $request, $session): JsonResponse
    {
        $eventId = (int)$request->input('event_id', 1);
        $event = Event::find($eventId);
        $cafeId = $event?->cafe_id ?? \App\Models\Cafe::first()?->id;
        $timerSetting = TimerSetting::where('event_id', $eventId)->where('is_active', true)->first()
            ?? TimerSetting::resolveForCafe($cafeId);
        $durationSeconds = $timerSetting->session_timeout_seconds ?? 360;

        $sessionModel = is_numeric($session) ? Session::find((int)$session) : ($session instanceof Session ? $session : null);
        if (!$sessionModel) {
            $sessionModel = Session::create([
                'cafe_id'    => $cafeId,
                'event_id'   => $eventId,
                'frame_id'   => $request->input('frame_id'),
                'status'     => 'active',
                'started_at' => now(),
                'expires_at' => now()->addSeconds($durationSeconds),
            ]);
        } else {
            $sessionModel->update([
                'frame_id' => $request->input('frame_id'),
                'cafe_id'  => $sessionModel->cafe_id ?? $cafeId,
            ]);
        }

        return response()->json([
            'success' => true,
            'data'    => ['session_id' => $sessionModel->id],
            'message' => 'Frame disimpan.',
        ]);
    }

    /**
     * Upload captured photos with the selected filter.
     * Transitions session status to processing.
     */
    public function uploadPhotos(Request $request, $session): JsonResponse
    {
        $sessionModel = is_numeric($session) ? Session::find((int)$session) : ($session instanceof Session ? $session : null);
        if (!$sessionModel) {
            $eventId = (int)$request->input('event_id', 1);
            $event = Event::find($eventId);
            $cafeId = $event?->cafe_id ?? \App\Models\Cafe::first()?->id;
            $sessionModel = Session::create([
                'cafe_id'    => $cafeId,
                'event_id'   => $eventId,
                'status'     => 'processing',
                'started_at' => now(),
                'expires_at' => now()->addMinutes(5),
            ]);
        }

        if ($request->filled('filter_id')) {
            $sessionModel->update([
                'filter_id'       => $request->filter_id,
                'selected_filter' => $request->selected_filter,
            ]);
        }

        if ($request->hasFile('photos')) {
            $files = $request->file('photos');
            if (!is_array($files)) $files = [$files];
            foreach ($files as $file) {
                $path = $file->store('photos', 'public');
                Photo::create([
                    'session_id' => $sessionModel->id,
                    'file_url'   => $path,
                    'type'       => 'raw',
                ]);
            }
        } elseif ($request->filled('photos') && is_array($request->photos)) {
            foreach ($request->photos as $photo) {
                Photo::create([
                    'session_id' => $sessionModel->id,
                    'file_url'   => is_array($photo) ? ($photo['url'] ?? '') : $photo,
                    'type'       => is_array($photo) ? ($photo['type'] ?? 'raw') : 'raw',
                ]);
            }
        }

        $sessionModel->update(['status' => 'processing']);

        return response()->json([
            'success' => true,
            'data'    => ['session_id' => $sessionModel->id],
            'message' => 'Foto disimpan.',
        ]);
    }

    /**
     * Generate HD Photo Strip, Animated GIF, and QR Code Download Link (7 days).
     */
    public function generateResult(Request $request, $session, \App\Services\GenerateResultService $generator): JsonResponse
    {
        $sessionModel = is_numeric($session) ? Session::find((int)$session) : ($session instanceof Session ? $session : null);
        if (!$sessionModel) {
            $eventId = (int)$request->input('event_id', 1);
            $event = Event::find($eventId);
            $cafeId = $event?->cafe_id ?? \App\Models\Cafe::first()?->id;
            $sessionModel = Session::create([
                'cafe_id'         => $cafeId,
                'event_id'        => $eventId,
                'frame_id'        => $request->input('frame_id'),
                'filter_id'       => $request->input('filter_id'),
                'selected_filter' => $request->input('selected_filter'),
                'status'          => 'processing',
                'started_at'      => now()->subMinutes(2),
                'expires_at'      => now()->addMinutes(3),
            ]);
        }

        if ($request->filled('filter_id')) {
            $sessionModel->update([
                'filter_id'       => $request->filter_id,
                'selected_filter' => $request->selected_filter,
            ]);
        }

        if ($request->filled('frame_id')) {
            $sessionModel->update(['frame_id' => $request->frame_id]);
        }

        // Handle uploaded photo files from tablet (multipart/form-data)
        if ($request->hasFile('photos')) {
            $files = $request->file('photos');
            if (!is_array($files)) $files = [$files];
            foreach ($files as $file) {
                $path = $file->store('photos', 'public');
                Photo::create([
                    'session_id' => $sessionModel->id,
                    'file_url'   => $path,
                    'type'       => 'raw',
                ]);
            }
        } elseif ($request->hasFile('photo_files')) {
            $files = $request->file('photo_files');
            if (!is_array($files)) $files = [$files];
            foreach ($files as $file) {
                $path = $file->store('photos', 'public');
                Photo::create([
                    'session_id' => $sessionModel->id,
                    'file_url'   => $path,
                    'type'       => 'raw',
                ]);
            }
        } elseif ($request->filled('photos') && is_array($request->photos)) {
            foreach ($request->photos as $p) {
                Photo::create([
                    'session_id' => $sessionModel->id,
                    'file_url'   => is_array($p) ? ($p['url'] ?? '') : $p,
                    'type'       => 'raw',
                ]);
            }
        }

        // Generate HD Photo Strip + Animated GIF + 7 days QR Token
        $result = $generator->generate($sessionModel);

        $host = request()->getSchemeAndHttpHost();
        $downloadUrl = $host . '/d/' . $result->qr_token;

        return response()->json([
            'success' => true,
            'data'    => [
                'session_id'   => $sessionModel->id,
                'qr_token'     => $result->qr_token,
                'final_url'    => $result->final_url ? asset('storage/' . $result->final_url) : null,
                'gif_url'      => $result->gif_url ? asset('storage/' . $result->gif_url) : null,
                'download_url' => $downloadUrl,
                'expires_at'   => $result->expires_at,
            ],
            'message' => 'Hasil foto berhasil digenerate.',
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
