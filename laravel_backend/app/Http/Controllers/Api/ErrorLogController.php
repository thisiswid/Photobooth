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
            'device_id'   => 'nullable|string|max:100',
            'event_id'    => 'nullable|integer|exists:events,id',
            'category'    => 'required|string|in:network,payment,camera,api_fetch,system,hardware',
            'level'       => 'nullable|string|in:info,warning,error,critical',
            'title'       => 'required|string|max:255',
            'message'     => 'required|string',
            'context'     => 'nullable|array',
            'stack_trace' => 'nullable|string',
        ]);

        $log = ErrorLog::create([
            'device_id'   => $validated['device_id'] ?? null,
            'event_id'    => $validated['event_id'] ?? 1,
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
