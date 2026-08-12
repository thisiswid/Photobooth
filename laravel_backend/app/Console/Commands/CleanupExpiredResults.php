<?php

namespace App\Console\Commands;

use App\Models\Result;
use App\Models\Session;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class CleanupExpiredResults extends Command
{
    protected $signature   = 'lumabooth:cleanup';
    protected $description = 'Hapus foto, GIF, dan hasil yang sudah melewati 30 hari retensi';

    public function handle(): void
    {
        // Cleanup expired results (> 30 days)
        $expiredResults = Result::where('expires_at', '<', now())->get();

        foreach ($expiredResults as $result) {
            // TODO: delete files from cloud storage
            // StorageService::delete($result->final_url);
            // StorageService::delete($result->gif_url);
            $result->session->photos()->delete();
            $result->delete();
        }

        // Cleanup timed-out sessions yang tidak selesai > 24 jam
        $timedOut = Session::where('status', 'timeout')
            ->where('updated_at', '<', now()->subDay())
            ->count();

        Session::where('status', 'timeout')
            ->where('updated_at', '<', now()->subDay())
            ->delete();

        $this->info("Cleaned {$expiredResults->count()} expired results, {$timedOut} timed-out sessions.");
        Log::info('LumaBooth cleanup', [
            'expired_results' => $expiredResults->count(),
            'timed_out_sessions' => $timedOut,
        ]);
    }
}
