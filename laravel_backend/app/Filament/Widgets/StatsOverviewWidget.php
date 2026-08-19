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
        $cafeId = auth()->user()?->cafe_id;

        $sessionQuery = Session::query();
        $paymentQuery = Payment::query();
        $errorQuery = ErrorLog::query();

        if ($cafeId) {
            $sessionQuery->where(fn($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn($eq) => $eq->where('cafe_id', $cafeId)));
            $paymentQuery->whereHas('session', fn($sq) => $sq->where('cafe_id', $cafeId)->orWhereHas('event', fn($eq) => $eq->where('cafe_id', $cafeId)));
            $errorQuery->where(fn($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn($eq) => $eq->where('cafe_id', $cafeId)));
        }

        $todayErrors = (clone $errorQuery)->whereDate('created_at', today())->count();
        $todaySessions = (clone $sessionQuery)->whereDate('created_at', today())->count();
        $finishedSessions = (clone $sessionQuery)->where('status', 'finished')->whereDate('created_at', today())->count();
        $paidPayments = (clone $paymentQuery)->where('status', 'paid')->whereDate('created_at', today())->count();
        $todayRevenue = (clone $paymentQuery)->where('status', 'paid')->whereDate('created_at', today())->sum('amount');

        return [
            Stat::make('Total Sesi Hari Ini', $todaySessions)
                ->description('Sesi dibuat hari ini')
                ->color('info'),
            Stat::make('Sesi Selesai', $finishedSessions)
                ->description('Selesai hari ini')
                ->color('success'),
            Stat::make('Pembayaran Sukses', $paidPayments)
                ->description('Paid hari ini')
                ->color('warning'),
            Stat::make('Total Pendapatan', 'Rp ' . number_format($todayRevenue, 0, ',', '.'))
                ->description('Hari ini')
                ->color('success'),
            Stat::make('Status Sistem & Error', $todayErrors > 0 ? "{$todayErrors} Insiden Hari Ini" : 'Semua Berjalan Normal')
                ->description($todayErrors > 0 ? 'Perlu perhatian staf' : '0 error sinyal / kamera / sistem')
                ->color($todayErrors > 0 ? 'danger' : 'success')
                ->icon($todayErrors > 0 ? 'heroicon-o-exclamation-triangle' : 'heroicon-o-check-badge'),
        ];
    }
}
