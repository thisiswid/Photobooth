<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\PakasirSettingResource\Pages;
use App\Models\PakasirSetting;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class PakasirSettingResource extends Resource
{
    protected static ?string $model = PakasirSetting::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-qr-code'; }
    public static function getNavigationGroup(): string { return 'Platform & Core Config'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Konfigurasi Pakasir'; }
    public static function getPluralModelLabel(): string { return 'QRIS Pakasir'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Gateway QRIS Pakasir')
                ->description('Konfigurasi ini dipakai bersama oleh semua cafe. Setiap transaksi tetap tercatat pada cafe pemilik perangkat.')
                ->schema([
                    TextInput::make('project_slug')
                        ->label('Project Slug Pakasir')
                        ->placeholder('contoh: snaptechbooth')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('api_key')
                        ->label('API Key Pakasir')
                        ->password()
                        ->revealable()
                        ->required()
                        ->helperText('Disimpan terenkripsi menggunakan APP_KEY server.'),
                    Toggle::make('is_enabled')
                        ->label('Aktifkan QRIS Pakasir')
                        ->default(true)
                        ->columnSpanFull(),
                ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('project_slug')->label('Project Slug'),
            IconColumn::make('api_key_configured')->label('API Key')->boolean()
                ->state(fn (PakasirSetting $record) => filled($record->api_key)),
            IconColumn::make('is_enabled')->label('QRIS Aktif')->boolean(),
            TextColumn::make('updated_at')->label('Terakhir Diubah')->dateTime('d M Y H:i'),
        ])->actions([
            EditAction::make()->label('Ubah Konfigurasi'),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPakasirSettings::route('/'),
            'create' => Pages\CreatePakasirSetting::route('/create'),
            'edit' => Pages\EditPakasirSetting::route('/{record}/edit'),
        ];
    }
}
