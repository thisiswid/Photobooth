<?php

namespace App\Jobs;

use App\Models\PhotoSession;
use App\Services\GenerateResultService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class GenerateResultJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 120;

    public function __construct(
        private readonly PhotoSession $session,
        private readonly string $jobId,
    ) {}

    public function handle(GenerateResultService $service): void
    {
        try {
            $stripPath = $service->generateStrip($this->session);
            $gifPath   = $service->generateGif($this->session);

            $this->session->update([
                'strip_path' => $stripPath,
                'gif_path'   => $gifPath,
            ]);

            Log::info("GenerateResultJob completed", [
                'session_code' => $this->session->session_code,
                'job_id'       => $this->jobId,
                'strip_path'   => $stripPath,
                'gif_path'     => $gifPath,
            ]);
        } catch (\Throwable $e) {
            Log::error("GenerateResultJob failed", [
                'session_code' => $this->session->session_code,
                'error'        => $e->getMessage(),
            ]);
            throw $e;
        }
    }
}
