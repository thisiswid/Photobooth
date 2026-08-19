<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalDeviceResource\Pages;
use App\Models\Device;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\TextEntry;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;

class GlobalDeviceResource extends Resource
{
    protected static ?string $model = Device::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-computer-desktop'; }
    public static function getNavigationGroup(): string { return 'Hardware & Fleet'; }
    public static function getNavigationSort(): int { return 2; }
    public static function getModelLabel(): string { return 'Mesin Photobooth'; }
    public static function getPluralModelLabel(): string { return 'Semua Mesin Booth'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Mesin & Alokasi Tenant')
                ->schema([
                    Select::make('cafe_id')
                        ->label('Alokasi Cafe / Tenant')
                        ->relationship('cafe', 'name')
                        ->searchable()
                        ->preload()
                        ->required(),
                    Select::make('event_id')
                        ->label('Event Aktif (Opsional)')
                        ->relationship('event', 'name')
                        ->searchable()
                        ->preload(),
                    TextInput::make('name')
                        ->label('Nama Mesin / Booth')
                        ->required()
                        ->placeholder('Contoh: Booth Utama - Lantai 1'),
                    TextInput::make('device_key')
                        ->label('Device Pairing Key')
                        ->default(fn () => Str::random(24))
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->helperText('Gunakan key ini untuk pairing aplikasi Flutter Photobooth dengan server'),
                ])->columns(2),

            Section::make('Status & Telemetri')
                ->schema([
                    Select::make('platform')
                        ->label('Platform')
                        ->options([
                            'android' => 'Android (Tablet / Kiosk)',
                            'windows' => 'Windows (PC / Kiosk)',
                            'ios'     => 'iOS (iPad)',
                            'web'     => 'Web / ChromeOS',
                        ])
                        ->default('android')
                        ->required(),
                    Select::make('status')
                        ->label('Status Operasional')
                        ->options([
                            'active'   => 'Active (Siap Pakai)',
                            'inactive' => 'Inactive (Mati / Maintenance)',
                        ])
                        ->default('active')
                        ->required(),
                    TextInput::make('ip_address')
                        ->label('IP Address Terakhir')
                        ->disabled(),
                ])->columns(3),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Mesin & Alokasi Tenant')->schema([
                TextEntry::make('name')->label('Nama Mesin / Booth')->weight('bold'),
                TextEntry::make('cafe.name')->label('Alokasi Cafe / Tenant')->badge()->color('primary'),
                TextEntry::make('event.name')->label('Event Aktif')->default('Semua / Default'),
                TextEntry::make('device_key')->label('Device Pairing Key')->copyable()->badge()->color('info'),
                TextEntry::make('platform')->label('Platform / OS')->badge(),
                TextEntry::make('status')->label('Status Operasional')->badge()
                    ->color(fn ($state) => $state === 'active' ? 'success' : 'danger'),
            ])->columns(3),

            Section::make('Status Koneksi & Statistik')->schema([
                TextEntry::make('ip_address')->label('IP Address Terakhir')->default('-'),
                TextEntry::make('last_seen_at')->label('Terakhir Online / Heartbeat')->since()->placeholder('Belum pernah online'),
                TextEntry::make('sessions_count')->label('Total Sesi Foto Dilayani')
                    ->state(fn ($record) => $record->sessions()->count() . ' Sesi'),
                TextEntry::make('created_at')->label('Terdaftar Pada')->dateTime('d M Y H:i:s'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('Nama Mesin')
                    ->searchable()
                    ->sortable()
                    ->description(fn (Device $record): string => "Key: " . ($record->device_key ?? '-')),
                TextColumn::make('cafe.name')
                    ->label('Lokasi Cafe')
                    ->searchable()
                    ->sortable()
                    ->badge()
                    ->color('primary'),
                TextColumn::make('platform')
                    ->label('Platform')
                    ->badge(),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => $state === 'active' ? 'success' : 'danger'),
                TextColumn::make('last_seen_at')
                    ->label('Terakhir Online')
                    ->since()
                    ->placeholder('Belum pernah')
                    ->sortable(),
                TextColumn::make('sessions_count')
                    ->label('Total Sesi')
                    ->counts('sessions')
                    ->badge()
                    ->color('info')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('cafe', 'name'),
                SelectFilter::make('status')
                    ->options([
                        'active'   => 'Active',
                        'inactive' => 'Inactive',
                    ]),
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
            'index'  => Pages\ListGlobalDevices::route('/'),
            'create' => Pages\CreateGlobalDevice::route('/create'),
            'edit'   => Pages\EditGlobalDevice::route('/{record}/edit'),
        ];
    }
}
