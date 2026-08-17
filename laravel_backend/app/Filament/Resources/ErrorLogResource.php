<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ErrorLogResource\Pages;
use App\Models\ErrorLog;
use Filament\Schemas\Schema;
use Filament\Infolists\Components\KeyValueEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\DeleteAction;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class ErrorLogResource extends Resource
{
    protected static ?string $model = ErrorLog::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-shield-exclamation'; }
    public static function getNavigationGroup(): string { return 'Sistem'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Log Error'; }
    public static function getPluralModelLabel(): string { return 'Log Error & Diagnostik'; }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Ringkasan Insiden Error')->schema([
                TextEntry::make('id')->label('Log ID'),
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
                    })
                    ->color(fn ($state) => match ($state) {
                        'network'   => 'warning',
                        'payment'   => 'danger',
                        'camera'    => 'danger',
                        'api_fetch' => 'warning',
                        default     => 'gray',
                    }),
                TextEntry::make('device_id')->label('ID Perangkat (Tablet)')->default('-'),
                TextEntry::make('ip_address')->label('Alamat IP')->default('-'),
                TextEntry::make('created_at')->label('Waktu Kejadian')->dateTime('d M Y H:i:s'),
            ])->columns(3),

            Section::make('Detail Pesan & Keterangan')->schema([
                TextEntry::make('title')->label('Judul Error')->columnSpanFull()->weight('bold'),
                TextEntry::make('message')->label('Pesan Kesalahan')->columnSpanFull(),
            ]),

            Section::make('Informasi Konteks Tambahan (Context Payload)')->schema([
                TextEntry::make('context')
                    ->label('Metadata JSON')
                    ->state(fn ($record) => $record->context ? json_encode($record->context, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) : 'Tidak ada metadata tambahan')
                    ->columnSpanFull()
                    ->fontFamily('mono'),
            ])->collapsed(),

            Section::make('Stack Trace Teknis')->schema([
                TextEntry::make('stack_trace')
                    ->label('Stack Trace')
                    ->default('Tidak ada stack trace')
                    ->columnSpanFull()
                    ->fontFamily('mono'),
            ])->collapsed(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
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
                        'network'   => '📶 Sinyal / Jaringan',
                        'payment'   => '💳 Pembayaran',
                        'camera'    => '📷 Kamera',
                        'api_fetch' => '🌐 Data API',
                        'hardware'  => '🖥️ Hardware',
                        default     => '⚙️ Sistem',
                    })
                    ->color(fn ($state) => match ($state) {
                        'network'   => 'warning',
                        'payment'   => 'danger',
                        'camera'    => 'danger',
                        'api_fetch' => 'warning',
                        default     => 'gray',
                    }),
                TextColumn::make('title')->label('Judul Masalah')->searchable()->limit(35),
                TextColumn::make('message')->label('Rincian Pesan')->limit(45)->searchable(),
                TextColumn::make('device_id')->label('Perangkat')->default('-')->limit(12),
                TextColumn::make('created_at')
                    ->label('Waktu Kejadian')
                    ->dateTime('d M Y H:i:s')
                    ->description(fn ($record) => $record->created_at->diffForHumans())
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->label('Kategori Masalah')
                    ->options([
                        'network'   => '📶 Sinyal / Koneksi',
                        'payment'   => '💳 Pembayaran Gagal',
                        'camera'    => '📷 Kamera & Jepret',
                        'api_fetch' => '🌐 Data API Gagal',
                        'hardware'  => '🖥️ Hardware',
                        'system'    => '⚙️ Sistem',
                    ]),
                SelectFilter::make('level')
                    ->label('Tingkat Keparahan')
                    ->options([
                        'critical' => 'Kritis (Critical)',
                        'error'    => 'Error',
                        'warning'  => 'Peringatan (Warning)',
                        'info'     => 'Info',
                    ]),
            ])
            ->actions([
                ViewAction::make()->label('Lihat Detail'),
                DeleteAction::make()->label('Hapus'),
            ])
            ->defaultSort('id', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListErrorLogs::route('/'),
        ];
    }
}
