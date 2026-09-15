<?php

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\Payment;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

class CafePerformanceWidget extends ChartWidget
{
    protected ?string $heading = 'Grafik Transaksi Platform (7 Hari Terakhir)';

    protected int|string|array $columnSpan = 'full';

    public static function getSort(): int
    {
        return 2;
    }

    protected function getData(): array
    {
        $days = collect(range(6, 0))->map(function ($daysAgo) {
            $date = Carbon::today()->subDays($daysAgo);
            $revenue = Payment::where('status', 'paid')
                ->where('is_simulated', false)
                ->whereDate('created_at', $date)
                ->sum('amount');
            $netRevenue = Payment::where('status', 'paid')
                ->where('is_simulated', false)
                ->whereDate('created_at', $date)
                ->sum('net_amount');

            return [
                'label' => $date->format('d M'),
                'revenue' => (int) $revenue,
                'net_revenue' => (int) $netRevenue,
            ];
        });

        return [
            'datasets' => [
                [
                    'label' => 'Omset Bruto (Rp)',
                    'data' => $days->pluck('revenue')->toArray(),
                    'backgroundColor' => 'rgba(99, 102, 241, 0.2)',
                    'borderColor' => '#6366f1',
                    'fill' => true,
                ],
                [
                    'label' => 'Neto Setelah Biaya Pakasir (Rp)',
                    'data' => $days->pluck('net_revenue')->toArray(),
                    'backgroundColor' => 'rgba(34, 197, 94, 0.12)',
                    'borderColor' => '#22c55e',
                    'fill' => true,
                ],
            ],
            'labels' => $days->pluck('label')->toArray(),
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
