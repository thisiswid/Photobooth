<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TimerSettingResource\Pages;
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
use Filament\Tables\Table;

class TimerSettingResource extends Resource
{
    protected static ?string $model = TimerSetting::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-clock'; }
    public static function getNavigationGroup(): string { return 'Konfigurasi'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Pengaturan Timer'; }
    public static function getPluralModelLabel(): string { return 'Pengaturan Timer'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi & Status Timer')
                ->description('Pengaturan timer hitung mundur dan batas durasi operasional photobooth')
                ->schema([
                    TextInput::make('name')
                        ->label('Nama Profil Timer')
                        ->required()
                        ->placeholder('Contoh: Standar Timer Cafe, Fast Booth Timer')
                        ->maxLength(255),
                    Select::make('event_id')
                        ->label('Event Terkait (Opsional)')
                        ->relationship(
                            name: 'event',
                            titleAttribute: 'name',
                            modifyQueryUsing: fn ($query) => auth()->user()?->cafe_id ? $query->where('cafe_id', auth()->user()->cafe_id) : $query
                        )
                        ->searchable()
                        ->preload()
                        ->helperText('Kosongkan jika berlaku untuk seluruh event di cafe ini'),
                    Toggle::make('is_active')
                        ->label('Status Aktif')
                        ->helperText('Hanya timer aktif yang akan diterapkan di mesin photobooth')
                        ->default(true),
                ])->columns(3),

            Section::make('Konfigurasi Durasi Waktu (Detik)')
                ->description('Tentukan batas waktu untuk setiap tahapan alur foto')
                ->schema([
                    TextInput::make('camera_countdown_seconds')
                        ->label('Hitung Mundur Kamera (Per Foto)')
                        ->helperText('Waktu ancang-ancang sebelum kamera menjepret foto (Default: 5 detik)')
                        ->numeric()
                        ->minValue(1)
                        ->maxValue(60)
                        ->default(5)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('session_timeout_seconds')
                        ->label('Batas Total Durasi Sesi')
                        ->helperText('Maksimal waktu dari mulai foto hingga selesai (Default: 300 detik / 5 menit)')
                        ->numeric()
                        ->minValue(30)
                        ->maxValue(3600)
                        ->default(300)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('payment_timeout_seconds')
                        ->label('Batas Waktu Pembayaran QRIS')
                        ->helperText('Batas waktu customer menyelesaikan scan QRIS (Default: 120 detik / 2 menit)')
                        ->numeric()
                        ->minValue(30)
                        ->maxValue(1800)
                        ->default(120)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('result_screen_timeout_seconds')
                        ->label('Auto-Reset Layar Hasil (Download QR)')
                        ->helperText('Batas waktu tampil hasil sebelum otomatis kembali ke layar awal (Default: 60 detik)')
                        ->numeric()
                        ->minValue(10)
                        ->maxValue(600)
                        ->default(60)
                        ->suffix('Detik')
                        ->required(),
                    TextInput::make('retake_timeout_seconds')
                        ->label('Batas Waktu Retake / Pilih Foto')
                        ->helperText('Batas waktu customer memilih foto atau mengulang jepret (Default: 60 detik)')
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
                TextEntry::make('event.name')->label('Event Terkait')->placeholder('Semua Event'),
                IconEntry::make('is_active')->label('Status Aktif')->boolean(),
            ])->columns(3),

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
                TextColumn::make('event.name')->label('Event')->placeholder('Semua Event')->sortable(),
                TextColumn::make('camera_countdown_seconds')->label('Kamera')->suffix('s')->sortable(),
                TextColumn::make('session_timeout_seconds')->label('Batas Sesi')
                    ->formatStateUsing(fn ($state) => "{$state}s (" . round($state / 60, 1) . "m)"),
                TextColumn::make('payment_timeout_seconds')->label('Batas Bayar')->suffix('s'),
                TextColumn::make('result_screen_timeout_seconds')->label('Reset Hasil')->suffix('s'),
                IconColumn::make('is_active')->label('Aktif')->boolean()->sortable(),
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListTimerSettings::route('/'),
            'create' => Pages\CreateTimerSetting::route('/create'),
            'edit'   => Pages\EditTimerSetting::route('/{record}/edit'),
        ];
    }
}
