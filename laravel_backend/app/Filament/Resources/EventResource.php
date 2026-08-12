<?php

namespace App\Filament\Resources;

use App\Filament\Resources\EventResource\Pages;
use App\Models\Event;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;
use Filament\Resources\Resource;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class EventResource extends Resource
{
    protected static ?string $model = Event::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-calendar-days'; }
    public static function getNavigationGroup(): string { return 'Konten'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Event'; }
    public static function getPluralModelLabel(): string { return 'Events'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')->label('Nama Event')->required()->maxLength(255),
            Textarea::make('description')->label('Deskripsi')->rows(3)->columnSpanFull(),
            DateTimePicker::make('starts_at')->label('Mulai')->native(false),
            DateTimePicker::make('ends_at')->label('Selesai')->native(false),
            Toggle::make('active')->label('Aktif')->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable()->sortable(),
                TextColumn::make('starts_at')->label('Mulai')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('ends_at')->label('Selesai')->dateTime('d M Y H:i')->sortable(),
                IconColumn::make('active')->label('Aktif')->boolean(),
                TextColumn::make('sessions_count')->label('Sesi')->counts('sessions')->sortable(),
            ])
            ->filters([TernaryFilter::make('active')->label('Aktif')])
            ->actions([EditAction::make(), DeleteAction::make()])
            ->bulkActions([BulkActionGroup::make([DeleteBulkAction::make()])]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListEvents::route('/'),
            'create' => Pages\CreateEvent::route('/create'),
            'edit'   => Pages\EditEvent::route('/{record}/edit'),
        ];
    }
}
