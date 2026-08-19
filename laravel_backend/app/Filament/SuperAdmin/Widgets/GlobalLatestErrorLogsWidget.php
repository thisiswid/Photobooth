<?php

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\ErrorLog;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class GlobalLatestErrorLogsWidget extends BaseWidget
{
    protected static ?string $heading = '🚨 Insiden & Error Mesin Terbaru (Semua Cafe)';
    protected int | string | array $columnSpan = 'full';
    public static function getSort(): int { return 3; }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                ErrorLog::query()->latest()->limit(5)
            )
            ->columns([
                TextColumn::make('created_at')
                    ->label('Waktu')
                    ->since()
                    ->sortable(),
                TextColumn::make('cafe.name')
                    ->label('Tenant Cafe')
                    ->badge()
                    ->color('primary')
                    ->placeholder('-'),
                TextColumn::make('device.name')
                    ->label('Mesin Booth')
                    ->placeholder('-'),
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
                        'network'   => '📶 Sinyal',
                        'payment'   => '💳 Bayar',
                        'camera'    => '📷 Kamera',
                        'hardware'  => '🖥️ Hardware',
                        default     => '⚙️ Sistem',
                    }),
                TextColumn::make('title')
                    ->label('Masalah')
                    ->limit(45),
            ])
            ->paginated(false)
            ->poll('10s');
    }
}
