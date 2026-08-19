<?php

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\Payment;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

class CafePerformanceWidget extends ChartWidget
{
    protected ?string $heading = 'Grafik Transaksi Platform (7 Hari Terakhir)';
    protected int|string|array $columnSpan = 'full';
    public static function getSort(): int { return 2; }

    protected function getData(): array
    {
        $days = collect(range(6, 0))->map(function ($daysAgo) {
            $date = Carbon::today()->subDays($daysAgo);
            $revenue = Payment::where('status', 'paid')
                ->whereDate('created_at', $date)
                ->sum('amount');

            return [
                'label'   => $date->format('d M'),
                'revenue' => (int) $revenue,
            ];
        });

        return [
            'datasets' => [
                [
                    'label'           => 'Total Omset Transaksi (Rp)',
                    'data'            => $days->pluck('revenue')->toArray(),
                    'backgroundColor' => 'rgba(99, 102, 241, 0.2)',
                    'borderColor'     => '#6366f1',
                    'fill'            => true,
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
