<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalEventResource\Pages;
use App\Models\Event;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalEventResource extends Resource
{
    protected static ?string $model = Event::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-calendar'; }
    public static function getNavigationGroup(): string { return 'Konten & Event'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Event Cafe'; }
    public static function getPluralModelLabel(): string { return 'Semua Event Cafe'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Event & Alokasi Cafe')->schema([
                Select::make('cafe_id')
                    ->label('Alokasi Cafe / Tenant')
                    ->relationship('cafe', 'name')
                    ->searchable()
                    ->preload()
                    ->required(),
                TextInput::make('name')
                    ->label('Nama Event')
                    ->required()
                    ->maxLength(255),
                Textarea::make('description')
                    ->label('Deskripsi')
                    ->columnSpanFull(),
                DateTimePicker::make('starts_at')
                    ->label('Waktu Mulai')
                    ->native(false),
                DateTimePicker::make('ends_at')
                    ->label('Waktu Selesai')
                    ->native(false),
                Toggle::make('active')
                    ->label('Event Aktif')
                    ->default(true),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama Event')->searchable()->sortable()->weight('bold'),
                TextColumn::make('cafe.name')->label('Lokasi Cafe')->badge()->color('primary')->searchable()->sortable(),
                IconColumn::make('active')->label('Aktif')->boolean()->sortable(),
                TextColumn::make('starts_at')->label('Mulai')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('ends_at')->label('Selesai')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('frames_count')->label('Total Frame')->counts('frames')->badge()->color('info'),
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
            'index'  => Pages\ListGlobalEvents::route('/'),
            'create' => Pages\CreateGlobalEvent::route('/create'),
            'edit'   => Pages\EditGlobalEvent::route('/{record}/edit'),
        ];
    }
}
