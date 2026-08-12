<?php

namespace App\Filament\Resources;

use App\Filament\Resources\FilterResource\Pages;
use App\Models\Filter;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;
use Filament\Resources\Resource;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class FilterResource extends Resource
{
    protected static ?string $model = Filter::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-adjustments-horizontal'; }
    public static function getNavigationGroup(): string { return 'Konten'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Filter'; }
    public static function getPluralModelLabel(): string { return 'Filters'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('event_id')->label('Event')
                ->relationship('event', 'name')->searchable()->preload(),
            TextInput::make('name')->label('Nama Filter')->required()->maxLength(255),
            FileUpload::make('thumbnail_url')->label('Thumbnail')
                ->image()->directory('filters')->columnSpanFull(),
            TextInput::make('parameters')->label('Parameters')->maxLength(500),
            TextInput::make('sort_order')->label('Urutan')->numeric()->default(0),
            Toggle::make('active')->label('Aktif')->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('thumbnail_url')->label('Thumbnail')->square(),
                TextColumn::make('name')->label('Nama')->searchable()->sortable(),
                TextColumn::make('event.name')->label('Event')->sortable(),
                TextColumn::make('sort_order')->label('Urutan')->sortable(),
                IconColumn::make('active')->label('Aktif')->boolean(),
            ])
            ->defaultSort('sort_order')
            ->filters([TernaryFilter::make('active')->label('Aktif')])
            ->actions([EditAction::make(), DeleteAction::make()])
            ->bulkActions([BulkActionGroup::make([DeleteBulkAction::make()])])
            ->reorderable('sort_order');
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListFilters::route('/'),
            'create' => Pages\CreateFilter::route('/create'),
            'edit'   => Pages\EditFilter::route('/{record}/edit'),
        ];
    }
}
