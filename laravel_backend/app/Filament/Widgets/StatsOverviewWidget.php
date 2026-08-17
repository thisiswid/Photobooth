<?php

namespace App\Filament\Widgets;

use App\Models\ErrorLog;
use App\Models\Payment;
use App\Models\Session;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverviewWidget extends BaseWidget
{
    public static function getSort(): int { return 1; }

    protected function getStats(): array
    {
        $todayErrors = ErrorLog::whereDate('created_at', today())->count();

        return [
            Stat::make('Total Sesi Hari Ini', Session::whereDate('created_at', today())->count())
                ->description('Sesi dibuat hari ini')
                ->color('info'),
            Stat::make('Sesi Selesai', Session::where('status', 'finished')->whereDate('created_at', today())->count())
                ->description('Selesai hari ini')
                ->color('success'),
            Stat::make('Pembayaran Sukses', Payment::where('status', 'paid')->whereDate('created_at', today())->count())
                ->description('Paid hari ini')
                ->color('warning'),
            Stat::make('Total Pendapatan', 'Rp ' . number_format(
                Payment::where('status', 'paid')->whereDate('created_at', today())->sum('amount'), 0, ',', '.'
            ))
                ->description('Hari ini')
                ->color('success'),
            Stat::make('Status Sistem & Error', $todayErrors > 0 ? "{$todayErrors} Insiden Hari Ini" : 'Semua Berjalan Normal')
                ->description($todayErrors > 0 ? 'Perlu perhatian staf' : '0 error sinyal / kamera / sistem')
                ->color($todayErrors > 0 ? 'danger' : 'success')
                ->icon($todayErrors > 0 ? 'heroicon-o-exclamation-triangle' : 'heroicon-o-check-badge'),
        ];
    }
}
