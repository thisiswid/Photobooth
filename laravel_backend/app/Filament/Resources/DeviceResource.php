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

class DeviceResource extends Resource
{
    protected static ?string $model = Device::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-device-tablet'; }
    public static function getNavigationGroup(): string { return 'Hardware'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Perangkat'; }
    public static function getPluralModelLabel(): string { return 'Perangkat'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('event_id')->label('Event')
                ->relationship('event', 'name')->searchable()->preload(),
            TextInput::make('name')->label('Nama')->required()->maxLength(255),
            Select::make('platform')->label('Platform')
                ->options(['android' => 'Android', 'ios' => 'iOS', 'web' => 'Web'])
                ->default('android'),
            Select::make('status')->label('Status')
                ->options(['active' => 'Active', 'inactive' => 'Inactive'])
                ->default('active'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable()->sortable(),
                TextColumn::make('event.name')->label('Event'),
                TextColumn::make('platform')->label('Platform')->badge(),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => $state === 'active' ? 'success' : 'gray'),
            ])
            ->filters([SelectFilter::make('status')->options(['active' => 'Active', 'inactive' => 'Inactive'])])
            ->actions([EditAction::make(), DeleteAction::make()]);
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
