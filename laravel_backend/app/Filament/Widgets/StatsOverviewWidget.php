<?php

namespace App\Filament\Widgets;

use App\Models\Cafe;
use App\Models\ErrorLog;
use App\Models\Payment;
use App\Models\Session;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverviewWidget extends BaseWidget
{
    public static function getSort(): int
    {
        return 1;
    }

    protected function getStats(): array
    {
        $cafeId = auth()->user()?->cafe_id;

        $sessionQuery = Session::query();
        $paymentQuery = Payment::query();
        $errorQuery = ErrorLog::query();

        if ($cafeId) {
            $sessionQuery->where(fn ($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId)));
            $paymentQuery->whereHas('session', fn ($sq) => $sq->where('cafe_id', $cafeId)->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId)));
            $errorQuery->where(fn ($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId)));
        }

        $todayErrors = (clone $errorQuery)->whereDate('created_at', today())->count();
        $todaySessions = (clone $sessionQuery)->whereDate('created_at', today())->count();
        $finishedSessions = (clone $sessionQuery)->where('status', 'finished')->whereDate('created_at', today())->count();
        $paidPayments = (clone $paymentQuery)->where('status', 'paid')->where('is_simulated', false)->whereDate('created_at', today())->count();
        $todayRevenue = (clone $paymentQuery)->where('status', 'paid')->where('is_simulated', false)->whereDate('created_at', today())->sum('amount');
        $todayPakasirFee = (clone $paymentQuery)->where('status', 'paid')->where('is_simulated', false)->whereDate('created_at', today())->sum('provider_fee');
        $todayNetRevenue = (clone $paymentQuery)->where('status', 'paid')->where('is_simulated', false)->whereDate('created_at', today())->sum('net_amount');
        $simulationRevenue = (clone $paymentQuery)->where('status', 'paid')->where('is_simulated', true)->whereDate('created_at', today())->sum('amount');
        $cafe = $cafeId ? Cafe::find($cafeId) : null;

        return [
            Stat::make('Total Sesi Hari Ini', $todaySessions)
                ->description('Sesi dibuat hari ini')
                ->icon('heroicon-o-camera')
                ->color('info'),
            Stat::make('Sesi Selesai', $finishedSessions)
                ->description('Selesai hari ini')
                ->icon('heroicon-o-check-circle')
                ->color('success'),
            Stat::make('Pembayaran Sukses', $paidPayments)
                ->description('Transaksi dana asli hari ini')
                ->icon('heroicon-o-credit-card')
                ->color('warning'),
            Stat::make('Omzet Bruto Hari Ini', 'Rp '.number_format($todayRevenue, 0, ',', '.'))
                ->description('Neto Rp '.number_format($todayNetRevenue, 0, ',', '.').' • biaya Pakasir Rp '.number_format($todayPakasirFee, 0, ',', '.').' • simulasi Rp '.number_format($simulationRevenue, 0, ',', '.'))
                ->icon('heroicon-o-banknotes')
                ->color('success'),
            Stat::make('Saldo Siap Ditarik', 'Rp '.number_format($cafe?->available_balance ?? 0, 0, ',', '.'))
                ->description($cafe && $cafe->pending_withdrawal > 0
                    ? 'Pending: Rp '.number_format($cafe->pending_withdrawal, 0, ',', '.')
                    : 'Sesuai data transaksi dan pencairan')
                ->icon('heroicon-o-wallet')
                ->color('success'),
            Stat::make('Status Sistem & Error', $todayErrors > 0 ? "{$todayErrors} Insiden Hari Ini" : 'Semua Berjalan Normal')
                ->description($todayErrors > 0 ? 'Perlu perhatian staf' : '0 error sinyal / kamera / sistem')
                ->color($todayErrors > 0 ? 'danger' : 'success')
                ->icon($todayErrors > 0 ? 'heroicon-o-exclamation-triangle' : 'heroicon-o-check-badge'),
        ];
    }
}
