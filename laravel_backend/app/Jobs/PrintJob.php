<?php

namespace App\Jobs;

use App\Models\PhotoSession;
use App\Models\PrintJob;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Handles the actual printer communication.
 * Phase 1: mock with sleep delays.
 * Phase 2: replace inner logic with real CUPS / printer SDK calls.
 */
class PrintJob extends ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 2;
    public int $timeout = 90;

    public function __construct(private readonly PrintJob $printJob) {}

    public function handle(): void
    {
        try {
            $this->printJob->update(['status' => 'preparing']);
            sleep(2); // Phase 1: simulate prep

            $this->printJob->update(['status' => 'printing']);
            sleep(4); // Phase 1: simulate printing

            $this->printJob->update([
                'status'       => 'completed',
                'completed_at' => now(),
            ]);

            Log::info('PrintJob completed', ['print_id' => $this->printJob->id]);
        } catch (\Throwable $e) {
            $this->printJob->update([
                'status'        => 'error',
                'error_message' => $e->getMessage(),
            ]);
            Log::error('PrintJob failed', [
                'print_id' => $this->printJob->id,
                'error'    => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    public function failed(\Throwable $exception): void
    {
        $this->printJob->update([
            'status'        => 'error',
            'error_message' => $exception->getMessage(),
        ]);
    }
}
