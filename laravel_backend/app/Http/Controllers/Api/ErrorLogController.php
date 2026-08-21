<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ErrorLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class ErrorLogController extends Controller
{
    /**
     * Ingest error log / telemetry from Flutter photobooth client.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'cafe_id'     => 'nullable|integer|exists:cafes,id',
            'device_id'   => 'nullable|string|max:100',
            'event_id'    => 'nullable|integer|exists:events,id',
            'category'    => 'required|string|in:network,payment,camera,api_fetch,system,hardware',
            'level'       => 'nullable|string|in:info,warning,error,critical',
            'title'       => 'required|string|max:255',
            'message'     => 'required|string',
            'context'     => 'nullable|array',
            'stack_trace' => 'nullable|string',
        ]);

        $deviceId = $validated['device_id'] ?? null;
        $device = null;
        if ($deviceId) {
            $device = \App\Models\Device::where('device_key', $deviceId)
                ->orWhere('id', $deviceId)
                ->orWhere('name', $deviceId)
                ->first();
        }

        $eventId = $validated['event_id'] ?? $device?->event_id;
        $event = $eventId ? \App\Models\Event::find($eventId) : null;

        $cafeId = $validated['cafe_id']
            ?? $event?->cafe_id
            ?? $device?->cafe_id
            ?? \App\Models\Cafe::first()?->id;

        if (!$eventId) {
            $event = \App\Models\Event::where('cafe_id', $cafeId)->where('active', true)->first()
                ?? \App\Models\Event::where('cafe_id', $cafeId)->latest()->first()
                ?? \App\Models\Event::where('active', true)->first()
                ?? \App\Models\Event::first();
            $eventId = $event?->id;
        }

        $log = ErrorLog::create([
            'cafe_id'     => $cafeId,
            'device_id'   => $deviceId,
            'event_id'    => $eventId,
            'category'    => $validated['category'],
            'level'       => $validated['level'] ?? 'error',
            'title'       => $validated['title'],
            'message'     => $validated['message'],
            'context'     => $validated['context'] ?? null,
            'stack_trace' => $validated['stack_trace'] ?? null,
            'ip_address'  => $request->ip(),
        ]);

        if (in_array($log->level, ['error', 'critical'])) {
            Log::channel('single')->error("[Photobooth Client {$log->category}] {$log->title}: {$log->message}", [
                'device_id' => $log->device_id,
                'context'   => $log->context,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Log recorded successfully',
            'data'    => [
                'id' => $log->id,
            ],
        ], 201);
    }
}
