<?php

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\Result;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class ServerHealthWidget extends BaseWidget
{
    public static function getSort(): int { return 2; }

    protected function getStats(): array
    {
        // 1. Monitor Kapasitas Harddisk VPS (Root /)
        $diskPath = DIRECTORY_SEPARATOR === '\\' ? 'C:' : '/';
        $freeSpace = @disk_free_space($diskPath) ?: 0;
        $totalSpace = @disk_total_space($diskPath) ?: 1;
        $usedSpace = max(0, $totalSpace - $freeSpace);
        $usedPercentage = round(($usedSpace / $totalSpace) * 100, 1);

        $totalGb = round($totalSpace / (1024 * 1024 * 1024), 1);
        $freeGb = round($freeSpace / (1024 * 1024 * 1024), 1);
        $usedGb = round($usedSpace / (1024 * 1024 * 1024), 1);

        $diskColor = $usedPercentage > 85 ? 'danger' : ($usedPercentage > 70 ? 'warning' : 'success');
        $diskStatus = $usedPercentage > 85 ? 'Kritis (Perlu Pembersihan)' : ($usedPercentage > 70 ? 'Waspada' : 'Aman');

        // 2. Monitor Total File Hasil Foto & Media di Storage
        $totalResults = Result::count();
        $recentResults = Result::whereDate('created_at', today())->count();

        // 3. Status Foto Kedaluwarsa (> 30 Hari) Siap Cleanup
        $expiredResults = Result::where('created_at', '<', now()->subDays(30))->count();

        // 4. Memory & PHP Environment
        $phpMemUsed = round(memory_get_usage(true) / (1024 * 1024), 1);
        $memLimit = ini_get('memory_limit') ?: '512M';

        return [
            Stat::make('Kapasitas Disk VPS', "{$usedPercentage}% Terpakai")
                ->description("Tersisa {$freeGb} GB dari {$totalGb} GB ({$diskStatus})")
                ->icon('heroicon-o-server-stack')
                ->color($diskColor),

            Stat::make('Galeri & File Hasil Foto', number_format($totalResults, 0, ',', '.') . ' Sesi')
                ->description("+{$recentResults} sesi foto baru hari ini")
                ->icon('heroicon-o-photo')
                ->color('info'),

            Stat::make('Retensi Foto (> 30 Hari)', "{$expiredResults} Foto Usang")
                ->description($expiredResults > 0 ? 'Siap dibersihkan via cron job' : 'Storage bersih dan optimal')
                ->icon('heroicon-o-trash')
                ->color($expiredResults > 0 ? 'warning' : 'success'),

            Stat::make('PHP Memory & Environment', "{$phpMemUsed} MB / {$memLimit}")
                ->description('PHP ' . PHP_VERSION . ' • ' . PHP_OS_FAMILY)
                ->icon('heroicon-o-cpu-chip')
                ->color('primary'),
        ];
    }
}
