<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PhotoSession;
use App\Jobs\GenerateResultJob;
use App\Jobs\PrintJob as PrintJobQueue;
use App\Models\PrintJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PrintController extends Controller
{
    /**
     * Queue a print job for the session.
     */
    public function print(string $code): JsonResponse
    {
        $session = PhotoSession::with('printJobs')
                               ->where('session_code', $code)
                               ->firstOrFail();

        if (empty($session->strip_path)) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Hasil foto belum digenerate. Jalankan /generate terlebih dahulu.',
            ], 422);
        }

        $printJob = PrintJob::create([
            'session_id'   => $session->id,
            'status'       => 'pending',
            'copies'       => 1,
            'printer_name' => config('photobooth.printer.default'),
            'started_at'   => now(),
        ]);

        PrintJobQueue::dispatch($printJob);

        return response()->json([
            'success' => true,
            'data'    => ['print_id' => $printJob->id, 'status' => $printJob->status],
            'message' => 'Antrian cetak dibuat.',
        ], 201);
    }

    /**
     * Check the status of a print job.
     */
    public function status(int $printId): JsonResponse
    {
        $job = PrintJob::findOrFail($printId);

        return response()->json([
            'success' => true,
            'data'    => [
                'id'            => $job->id,
                'status'        => $job->status,
                'started_at'    => $job->started_at?->toIso8601String(),
                'completed_at'  => $job->completed_at?->toIso8601String(),
                'error_message' => $job->error_message,
            ],
            'message' => 'OK',
        ]);
    }

    /**
     * Retry a failed print job.
     */
    public function retry(int $printId): JsonResponse
    {
        $job = PrintJob::where('id', $printId)
                       ->where('status', 'error')
                       ->firstOrFail();

        $job->update(['status' => 'pending', 'error_message' => null, 'started_at' => now()]);
        PrintJobQueue::dispatch($job);

        return response()->json([
            'success' => true,
            'data'    => ['status' => $job->status],
            'message' => 'Print job di-retry.',
        ]);
    }
}
