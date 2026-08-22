<?php

namespace App\Filament\Resources;

use App\Filament\Resources\DeviceResource\Pages;
use App\Models\Device;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;
use Filament\Resources\Resource;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;

class DeviceResource extends Resource
{
    protected static ?string $model = Device::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-device-tablet'; }
    public static function getNavigationGroup(): string { return 'Hardware'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Perangkat / Mesin'; }
    public static function getPluralModelLabel(): string { return 'Perangkat / Mesin Kiosk'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')
                ->label('Nama Mesin / Kiosk')
                ->required()
                ->maxLength(255)
                ->placeholder('Contoh: Kiosk Utama Lantai 1'),
            TextInput::make('device_key')
                ->label('Device Pairing Key')
                ->default(fn () => 'FK-' . Str::upper(Str::random(8)))
                ->required()
                ->unique(ignoreRecord: true)
                ->helperText('Salin kode key ini dan masukkan ke layar Aktivasi Mesin Kiosk Flutter'),
            Select::make('event_id')
                ->label('Event Terkait')
                ->relationship(
                    name: 'event',
                    titleAttribute: 'name',
                    modifyQueryUsing: fn ($query) => auth()->user()?->cafe_id ? $query->where('cafe_id', auth()->user()->cafe_id) : $query
                )
                ->searchable()
                ->preload(),
            Select::make('platform')
                ->label('Platform')
                ->options([
                    'android' => 'Android (Tablet / Kiosk)',
                    'windows' => 'Windows (PC / Kiosk)',
                    'ios'     => 'iOS (iPad)',
                    'web'     => 'Web / Browser',
                ])
                ->default('android'),
            Select::make('status')
                ->label('Status')
                ->options([
                    'active'   => 'Active (Aktif)',
                    'inactive' => 'Inactive (Nonaktif)',
                ])
                ->default('active'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('Nama Mesin')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('device_key')
                    ->label('Device Pairing Key')
                    ->badge()
                    ->color('info')
                    ->copyable()
                    ->copyMessage('Device Key berhasil disalin!')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('event.name')
                    ->label('Event')
                    ->placeholder('Default'),
                TextColumn::make('platform')
                    ->label('Platform')
                    ->badge(),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => $state === 'active' ? 'success' : 'gray'),
                TextColumn::make('last_seen_at')
                    ->label('Heartbeat / Online')
                    ->since()
                    ->placeholder('Belum pernah')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')->options(['active' => 'Active', 'inactive' => 'Inactive']),
                SelectFilter::make('platform')->options(['android' => 'Android', 'windows' => 'Windows']),
            ])
            ->actions([
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
            'index'  => Pages\ListDevices::route('/'),
            'create' => Pages\CreateDevice::route('/create'),
            'edit'   => Pages\EditDevice::route('/{record}/edit'),
        ];
    }
}
