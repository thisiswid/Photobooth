<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalErrorLogResource\Pages;
use App\Models\ErrorLog;
use Filament\Actions\DeleteAction;
use Filament\Actions\ViewAction;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalErrorLogResource extends Resource
{
    protected static ?string $model = ErrorLog::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-shield-exclamation'; }
    public static function getNavigationGroup(): string { return 'Hardware & Fleet'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Log Diagnostik Mesin'; }
    public static function getPluralModelLabel(): string { return 'Log Diagnostik Mesin'; }

    public static function getNavigationBadge(): ?string
    {
        $count = static::getModel()::whereDate('created_at', today())->count();
        return $count > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'danger';
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Ringkasan Insiden Error')->schema([
                TextEntry::make('id')->label('Log ID'),
                TextEntry::make('cafe.name')->label('Tenant Cafe')->badge()->color('primary'),
                TextEntry::make('device.name')->label('Mesin Booth')->default('-'),
                TextEntry::make('level')
                    ->label('Tingkat Keparahan')
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'critical' => 'danger',
                        'error'    => 'danger',
                        'warning'  => 'warning',
                        default    => 'info',
                    }),
                TextEntry::make('category')
                    ->label('Kategori')
                    ->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'network'   => '📶 Sinyal / Koneksi',
                        'payment'   => '💳 Pembayaran Gagal',
                        'camera'    => '📷 Kamera & Jepret',
                        'api_fetch' => '🌐 Data API Gagal',
                        'hardware'  => '🖥️ Perangkat Keras',
                        default     => '⚙️ Sistem',
                    }),
                TextEntry::make('created_at')->label('Waktu Kejadian')->dateTime('d M Y, H:i:s'),
            ])->columns(3),

            Section::make('Pesan & Detail')->schema([
                TextEntry::make('title')->label('Judul Masalah')->weight('bold'),
                TextEntry::make('message')->label('Deskripsi Error')->columnSpanFull(),
                TextEntry::make('context')
                    ->label('Context Data (Diagnostik JSON)')
                    ->state(fn ($record) => $record->context ? json_encode($record->context, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) : 'Tidak ada metadata tambahan')
                    ->columnSpanFull()
                    ->fontFamily('mono'),
                TextEntry::make('stack_trace')->label('Stack Trace')->fontFamily('mono')->columnSpanFull(),
            ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')
                    ->label('Waktu')
                    ->dateTime('d M H:i:s')
                    ->sortable(),
                TextColumn::make('cafe.name')
                    ->label('Cafe / Tenant')
                    ->badge()
                    ->color('primary')
                    ->searchable()
                    ->placeholder('-'),
                TextColumn::make('level')
                    ->label('Level')
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
                    ->label('Judul Error')
                    ->searchable()
                    ->limit(40),
                TextColumn::make('device.name')
                    ->label('Mesin')
                    ->placeholder('-'),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('cafe', 'name'),
                SelectFilter::make('level')
                    ->options([
                        'critical' => 'Critical',
                        'error'    => 'Error',
                        'warning'  => 'Warning',
                        'info'     => 'Info',
                    ]),
            ])
            ->actions([
                ViewAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalErrorLogs::route('/'),
        ];
    }
}
