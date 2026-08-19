<?php

namespace App\Filament\Widgets;

use App\Models\ErrorLog;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class LatestErrorLogsWidget extends BaseWidget
{
    protected static ?string $heading = '🚨 Status & Log Masalah Mesin Terbaru';
    protected int | string | array $columnSpan = 'full';
    public static function getSort(): int { return 3; }

    public function table(Table $table): Table
    {
        $cafeId = auth()->user()?->cafe_id;
        $query = ErrorLog::query()->latest();

        if ($cafeId) {
            $query->where(fn($q) => $q->where('cafe_id', $cafeId)->orWhereHas('event', fn($eq) => $eq->where('cafe_id', $cafeId)));
        }

        return $table
            ->query($query->limit(5))
            ->columns([
                TextColumn::make('created_at')
                    ->label('Waktu')
                    ->since()
                    ->sortable(),
                TextColumn::make('device.name')
                    ->label('Perangkat / Booth')
                    ->placeholder('Booth Utama'),
                TextColumn::make('level')
                    ->label('Tingkat')
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'critical' => 'danger',
                        'error'    => 'danger',
                        'warning'  => 'warning',
                        default    => 'info',
                    }),
                TextColumn::make('category')
                    ->label('Kategori')
                    ->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'network'   => '📶 Jaringan',
                        'payment'   => '💳 Pembayaran',
                        'camera'    => '📷 Kamera',
                        'hardware'  => '🖥️ Hardware / Printer',
                        default     => '⚙️ Sistem',
                    }),
                TextColumn::make('title')
                    ->label('Detail Kendala')
                    ->limit(45),
            ])
            ->paginated(false)
            ->poll('10s');
    }
}
