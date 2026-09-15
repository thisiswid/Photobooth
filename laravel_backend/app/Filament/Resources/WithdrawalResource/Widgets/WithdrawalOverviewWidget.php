<?php

namespace App\Filament\Resources\WithdrawalResource\Widgets;

use App\Models\Cafe;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class WithdrawalOverviewWidget extends BaseWidget
{
    protected function getStats(): array
    {
        $cafeId = auth()->user()?->cafe_id;
        $cafe = $cafeId ? Cafe::find($cafeId) : null;

        if (! $cafe) {
            return [];
        }

        $totalRevenue = $cafe->total_revenue;
        $pakasirFee = $cafe->pakasir_fee;
        $netRevenue = $cafe->net_revenue;
        $availableBalance = $cafe->available_balance;
        $totalWithdrawn = $cafe->total_withdrawn;
        $pending = $cafe->pending_withdrawal;

        return [
            Stat::make('Saldo Siap Ditarik', 'Rp '.number_format($availableBalance, 0, ',', '.'))
                ->description($pending > 0 ? 'Pending diajukan: Rp '.number_format($pending, 0, ',', '.') : 'Tersedia untuk dicairkan')
                ->icon('heroicon-o-wallet')
                ->color('success'),

            Stat::make('Omset Bruto Photobooth', 'Rp '.number_format($totalRevenue, 0, ',', '.'))
                ->description('Neto setelah biaya: Rp '.number_format($netRevenue, 0, ',', '.'))
                ->icon('heroicon-o-arrow-trending-up')
                ->color('info'),

            Stat::make('Biaya Pakasir', '- Rp '.number_format($pakasirFee, 0, ',', '.'))
                ->description('Potongan platform tetap Rp 0 (nonaktif)')
                ->icon('heroicon-o-receipt-percent')
                ->color($pakasirFee > 0 ? 'danger' : 'success'),

            Stat::make('Total Dana Dicairkan', 'Rp '.number_format($totalWithdrawn, 0, ',', '.'))
                ->description('Telah berhasil ditransfer ke rekening')
                ->icon('heroicon-o-check-badge')
                ->color('primary'),
        ];
    }
}
