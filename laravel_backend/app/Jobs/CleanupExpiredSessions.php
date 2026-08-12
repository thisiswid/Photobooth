<?php

namespace App\Jobs;

use App\Models\PhotoSession;
use App\Services\StorageService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Deletes sessions that expired without being completed.
 * Scheduled daily at 02:00 via Laravel Scheduler.
 */
class CleanupExpiredSessions implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(private readonly StorageService $storage) {}

    public function handle(): void
    {
        $expired = PhotoSession::expired()->get();
        $count   = 0;

        foreach ($expired as $session) {
            try {
                // Delete cloud/local files for this session
                $this->storage->deleteDirectory("sessions/{$session->session_code}");
                $session->delete(); // cascade deletes photos + print_jobs
                $count++;
            } catch (\Throwable $e) {
                Log::warning("Cleanup failed for session {$session->session_code}", [
                    'error' => $e->getMessage(),
                ]);
            }
        }

        Log::info("CleanupExpiredSessions: removed $count sessions.");
    }
}
