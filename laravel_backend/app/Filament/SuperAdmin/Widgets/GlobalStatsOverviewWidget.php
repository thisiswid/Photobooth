<?php

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\Cafe;
use App\Models\Device;
use App\Models\ErrorLog;
use App\Models\Payment;
use App\Models\Session;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class GlobalStatsOverviewWidget extends BaseWidget
{
    public static function getSort(): int { return 1; }

    protected function getStats(): array
    {
        $activeCafes = Cafe::where('status', 'active')->count();
        $totalDevices = Device::count();
        $activeDevices = Device::where('status', 'active')->count();

        $todayRevenue = Payment::where('status', 'paid')->whereDate('created_at', today())->sum('amount');
        $monthRevenue = Payment::where('status', 'paid')->whereMonth('created_at', now()->month)->whereYear('created_at', now()->year)->sum('amount');

        // Estimate Platform Fee (average 10%)
        $todayPlatformFee = $todayRevenue * 0.10;

        $unresolvedErrors = ErrorLog::whereDate('created_at', today())->whereIn('level', ['critical', 'error'])->count();

        return [
            Stat::make('Cafe / Tenant Aktif', $activeCafes)
                ->description('Dari ' . Cafe::count() . ' total cafe terdaftar')
                ->icon('heroicon-o-building-storefront')
                ->color('primary'),

            Stat::make('Mesin Photobooth', "{$activeDevices} / {$totalDevices}")
                ->description('Mesin status siap pakai')
                ->icon('heroicon-o-computer-desktop')
                ->color('info'),

            Stat::make('Omset Global Hari Ini', 'Rp ' . number_format($todayRevenue, 0, ',', '.'))
                ->description('Fee Platform: Rp ' . number_format($todayPlatformFee, 0, ',', '.'))
                ->icon('heroicon-o-banknotes')
                ->color('success'),

            Stat::make('Omset Bulan Ini', 'Rp ' . number_format($monthRevenue, 0, ',', '.'))
                ->description(Payment::where('status', 'paid')->whereMonth('created_at', now()->month)->count() . ' transaksi berhasil')
                ->icon('heroicon-o-chart-bar')
                ->color('success'),

            Stat::make('Insiden Mesin Hari Ini', $unresolvedErrors > 0 ? "{$unresolvedErrors} Insiden" : 'Aman (0 Error)')
                ->description($unresolvedErrors > 0 ? 'Perlu pengecekan remote' : 'Semua mesin berjalan stabil')
                ->icon($unresolvedErrors > 0 ? 'heroicon-o-exclamation-triangle' : 'heroicon-o-check-badge')
                ->color($unresolvedErrors > 0 ? 'danger' : 'success'),
        ];
    }
}
