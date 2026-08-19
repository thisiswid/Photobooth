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
        $cafeId = auth()->user()?->cafe_id;

        $data = collect(range(6, 0))->map(function ($daysAgo) use ($cafeId) {
            $date = Carbon::today()->subDays($daysAgo);
            $query = Session::whereDate('created_at', $date);
            if ($cafeId) {
                $query->where(fn($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn($eq) => $eq->where('cafe_id', $cafeId)));
            }

            return [
                'label' => $date->format('d M'),
                'count' => $query->count(),
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
