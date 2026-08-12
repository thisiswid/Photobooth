<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhotoSession;
use App\Jobs\GenerateResultJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class ResultController extends Controller
{
    /**
     * Dispatch the generate-result job for a session.
     */
    public function generate(string $code): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)
                               ->where('payment_status', 'paid')
                               ->firstOrFail();

        if ($session->photos()->where('photo_type', 'individual')->count() === 0) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Belum ada foto yang diunggah.',
            ], 422);
        }

        $jobId = (string) Str::uuid();
        GenerateResultJob::dispatch($session, $jobId);

        return response()->json([
            'success' => true,
            'data'    => ['job_id' => $jobId],
            'message' => 'Generate dimulai.',
        ]);
    }

    /**
     * Return download URLs for generated assets.
     */
    public function download(string $code, string $type): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)->firstOrFail();

        $url = match($type) {
            'strip'  => $session->strip_path ? url("storage/{$session->strip_path}") : null,
            'gif'    => $session->gif_path   ? url("storage/{$session->gif_path}")   : null,
            'photos' => $session->photos()->where('photo_type', 'individual')
                                  ->pluck('file_path')
                                  ->map(fn($p) => url("storage/$p"))
                                  ->toArray(),
            default  => null,
        };

        if ($url === null) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Tipe tidak valid atau file belum tersedia.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => ['url' => $url],
            'message' => 'OK',
        ]);
    }
}
