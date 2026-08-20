<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource\Pages;
use App\Models\TimerSetting;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalTimerSettingResource extends Resource
{
    protected static ?string $model = TimerSetting::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-clock'; }
    public static function getNavigationGroup(): string { return 'Konfigurasi & Fleet'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Timer Photobooth'; }
    public static function getPluralModelLabel(): string { return 'Semua Pengaturan Timer'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Profil & Alokasi Cafe')
                ->description('Pengaturan durasi dan hitung mundur timer untuk operasional photobooth')
                ->schema([
                    Select::make('cafe_id')
                        ->label('Alokasi Cafe / Tenant')
                        ->relationship('cafe', 'name')
                        ->searchable()
                        ->preload()
                        ->placeholder('Global Default (Semua Cafe Tanpa Custom Timer)')
                        ->helperText('Kosongkan jika ini adalah profil default seluruh sistem'),
                    TextInput::make('name')
                        ->label('Nama Profil Timer')
                        ->required()
                        ->placeholder('Contoh: Standar Timer Global, Fast Booth Express')
                        ->maxLength(255),
                    Select::make('event_id')
                        ->label('Event Terkait (Opsional)')
                        ->relationship('event', 'name')
                        ->searchable()
                        ->preload()
                        ->helperText('Hanya aktif untuk event tertentu'),
                    Toggle::make('is_active')
                        ->label('Status Aktif')
                        ->default(true),
                ])->columns(2),

            Section::make('Rincian Durasi Waktu (Detik)')
                ->schema([
                    TextInput::make('camera_countdown_seconds')
                        ->label('Hitung Mundur Kamera (Per Foto)')
                        ->helperText('Waktu ancang-ancang jepret foto (Default: 5 detik)')
                        ->numeric()
                        ->minValue(1)
                        ->maxValue(60)
                        ->default(5)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('session_timeout_seconds')
                        ->label('Batas Total Durasi Sesi')
                        ->helperText('Batas waktu keseluruhan sesi (Default: 300 detik / 5 menit)')
                        ->numeric()
                        ->minValue(30)
                        ->maxValue(3600)
                        ->default(300)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('payment_timeout_seconds')
                        ->label('Batas Waktu Pembayaran QRIS')
                        ->helperText('Batas waktu scan QRIS (Default: 120 detik / 2 menit)')
                        ->numeric()
                        ->minValue(30)
                        ->maxValue(1800)
                        ->default(120)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('result_screen_timeout_seconds')
                        ->label('Auto-Reset Layar Hasil (Download QR)')
                        ->helperText('Batas tampil hasil sebelum kembali ke welcome (Default: 60 detik)')
                        ->numeric()
                        ->minValue(10)
                        ->maxValue(600)
                        ->default(60)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('retake_timeout_seconds')
                        ->label('Batas Waktu Retake / Pilih Foto')
                        ->helperText('Batas waktu memilih foto ulang (Default: 60 detik)')
                        ->numeric()
                        ->minValue(10)
                        ->maxValue(600)
                        ->default(60)
                        ->suffix('Detik')
                        ->required(),
                ])->columns(2),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Profil Timer')->schema([
                TextEntry::make('name')->label('Nama Profil Timer')->weight('bold'),
                TextEntry::make('cafe.name')->label('Lokasi Cafe')->badge()->color('primary')->placeholder('Global Default'),
                TextEntry::make('event.name')->label('Event')->placeholder('Semua Event'),
                IconEntry::make('is_active')->label('Status Aktif')->boolean(),
            ])->columns(4),

            Section::make('Rincian Durasi Waktu')->schema([
                TextEntry::make('camera_countdown_seconds')->label('Hitung Mundur Kamera')->suffix(' Detik'),
                TextEntry::make('session_timeout_seconds')->label('Total Batas Sesi')
                    ->formatStateUsing(fn ($state) => "{$state} Detik (" . round($state / 60, 1) . " Menit)"),
                TextEntry::make('payment_timeout_seconds')->label('Batas Waktu Bayar QRIS')
                    ->formatStateUsing(fn ($state) => "{$state} Detik (" . round($state / 60, 1) . " Menit)"),
                TextEntry::make('result_screen_timeout_seconds')->label('Auto Reset Layar Hasil')->suffix(' Detik'),
                TextEntry::make('retake_timeout_seconds')->label('Batas Waktu Retake')->suffix(' Detik'),
            ])->columns(3),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama Profil')->searchable()->sortable()->weight('bold'),
                TextColumn::make('cafe.name')->label('Cafe')->badge()->color('primary')->placeholder('Global Default')->searchable()->sortable(),
                TextColumn::make('camera_countdown_seconds')->label('Kamera')->suffix('s')->sortable(),
                TextColumn::make('session_timeout_seconds')->label('Batas Sesi')
                    ->formatStateUsing(fn ($state) => "{$state}s (" . round($state / 60, 1) . "m)"),
                TextColumn::make('payment_timeout_seconds')->label('Batas Bayar')->suffix('s'),
                TextColumn::make('result_screen_timeout_seconds')->label('Reset Hasil')->suffix('s'),
                IconColumn::make('is_active')->label('Aktif')->boolean()->sortable(),
            ])
            ->filters([
                SelectFilter::make('cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('cafe', 'name'),
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListGlobalTimerSettings::route('/'),
            'create' => Pages\CreateGlobalTimerSetting::route('/create'),
            'edit'   => Pages\EditGlobalTimerSetting::route('/{record}/edit'),
        ];
    }
}
