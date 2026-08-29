<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CafeResource\Pages;
use App\Models\Cafe;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class CafeResource extends Resource
{
    protected static ?string $model = Cafe::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-building-storefront'; }
    public static function getNavigationGroup(): string { return 'Konfigurasi'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Pengaturan Cafe & Harga'; }
    public static function getPluralModelLabel(): string { return 'Pengaturan Cafe & Harga'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi & Harga Photobooth')
                ->description('Pengaturan identitas cafe dan tarif harga QRIS untuk mesin photobooth')
                ->schema([
                    TextInput::make('name')
                        ->label('Nama Cafe / Booth')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('session_price')
                        ->label('Harga Sesi Photobooth (Rp)')
                        ->numeric()
                        ->default(25000)
                        ->prefix('Rp')
                        ->helperText('Nominal pembayaran QRIS yang akan muncul di layar mesin photobooth')
                        ->required(),
                    TextInput::make('code')
                        ->label('Kode Lisensi / Identifier')
                        ->disabled()
                        ->dehydrated(false)
                        ->helperText('Kode lisensi unik cafe Anda'),
                    FileUpload::make('logo_path')
                        ->label('Logo Cafe')
                        ->image()
                        ->directory('cafes/logos')
                        ->disk('public'),
                ])->columns(2),

            Section::make('Kontak & Lokasi')
                ->schema([
                    TextInput::make('pic_name')->label('Nama PIC / Penanggung Jawab')->maxLength(255),
                    TextInput::make('pic_phone')->label('WhatsApp / Telepon')->tel()->maxLength(50),
                    TextInput::make('pic_email')->label('Email')->email()->maxLength(255),
                    Textarea::make('address')->label('Alamat Lengkap Cafe / Lokasi Booth')->columnSpanFull(),
                ])->columns(3),

            Section::make('Fitur & Tampilan Kiosk')
                ->schema([
                    Toggle::make('show_kiosk_settings')
                        ->label('Tampilkan Tombol Setting di Layar Kiosk')
                        ->helperText('Jika diaktifkan, icon gear pengaturan akan muncul di pojok layar awal aplikasi booth')
                        ->default(true),
                    Toggle::make('is_ai_enabled')
                        ->label('Aktifkan Fitur AI (AI Vision)')
                        ->default(true),
                ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('Nama Cafe')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),
                TextColumn::make('session_price')
                    ->label('Harga Sesi')
                    ->money('IDR', locale: 'id_ID')
                    ->sortable()
                    ->badge()
                    ->color('success'),
                TextColumn::make('code')
                    ->label('Kode Lisensi')
                    ->badge()
                    ->color('info'),
                TextColumn::make('pic_phone')
                    ->label('WhatsApp PIC'),
                IconColumn::make('show_kiosk_settings')
                    ->label('Setting Kiosk')
                    ->boolean(),
            ])
            ->actions([
                EditAction::make()->label('Ubah Harga & Info'),
            ]);
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('id', $cafeId);
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListCafes::route('/'),
            'edit'  => Pages\EditCafe::route('/{record}/edit'),
        ];
    }
}
