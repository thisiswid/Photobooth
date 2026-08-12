<?php

namespace App\Filament\Widgets;

use App\Models\Session;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

class SessionChartWidget extends ChartWidget
{
    protected ?string $heading = 'Sesi per Hari (7 Hari Terakhir)';
    protected int|string|array $columnSpan = 'full';
    public static function getSort(): int { return 2; }

    protected function getData(): array
    {
        $data = collect(range(6, 0))->map(function ($daysAgo) {
            $date = Carbon::today()->subDays($daysAgo);
            return [
                'label' => $date->format('d M'),
                'count' => Session::whereDate('created_at', $date)->count(),
            ];
        });

        return [
            'datasets' => [[
                'label'           => 'Jumlah Sesi',
                'data'            => $data->pluck('count')->toArray(),
                'backgroundColor' => '#6366f1',
                'borderColor'     => '#6366f1',
            ]],
            'labels' => $data->pluck('label')->toArray(),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
