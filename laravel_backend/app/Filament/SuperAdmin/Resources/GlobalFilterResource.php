<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalFilterResource\Pages;
use App\Models\Filter;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalFilterResource extends Resource
{
    protected static ?string $model = Filter::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-adjustments-horizontal'; }
    public static function getNavigationGroup(): string { return 'Konten & Event'; }
    public static function getNavigationSort(): int { return 5; }
    public static function getModelLabel(): string { return 'Filter Foto'; }
    public static function getPluralModelLabel(): string { return 'Semua Filter Foto'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('event_id')
                ->label('Event / Cafe')
                ->relationship('event', 'name')
                ->searchable()
                ->preload()
                ->required(),
            TextInput::make('name')
                ->label('Nama Filter')
                ->required()
                ->maxLength(255),
            Select::make('parameters')
                ->label('Tipe Preset Filter')
                ->options([
                    '{"type":"none"}' => '🌿 Original / Normal (Warna Asli)',
                    '{"type":"grayscale"}' => '🎞️ Monochrome / Black & White Klasik',
                    '{"type":"sepia","intensity":80}' => '📻 Vintage Sepia Heritage',
                    '{"type":"warm","r":25,"g":10,"b":0,"brightness":10}' => '☕ Warm Coffee / Nostalgia',
                    '{"type":"cool","r":-10,"g":0,"b":25,"brightness":5}' => '❄️ Cool Mist / Nordic Chill',
                    '{"type":"soft","blur":1,"brightness":15}' => '🌸 Soft Glow / Pastel Dream',
                    '{"type":"contrast","level":30}' => '⚡ High Contrast / Vivid Film',
                    '{"type":"sunset","r":35,"g":15,"b":-10,"brightness":8}' => '🌅 Golden Hour / Sunset Glow',
                ])
                ->default('{"type":"none"}')
                ->required(),
            FileUpload::make('thumbnail_url')->label('Thumbnail (Opsional)')->image()->directory('filters'),
            TextInput::make('sort_order')->label('Urutan')->numeric()->default(0),
            Toggle::make('active')->label('Status Aktif')->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('thumbnail_url')->label('Thumbnail')->square()->disk('public'),
                TextColumn::make('name')->label('Nama Filter')->searchable()->sortable()->weight('bold'),
                TextColumn::make('event.cafe.name')->label('Cafe')->badge()->color('primary')->searchable()->sortable(),
                TextColumn::make('event.name')->label('Event')->placeholder('Main Booth')->sortable(),
                TextColumn::make('sort_order')->label('Urutan')->sortable(),
                IconColumn::make('active')->label('Aktif')->boolean()->sortable(),
            ])
            ->filters([
                SelectFilter::make('event.cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('event.cafe', 'name'),
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
            'index'  => Pages\ListGlobalFilters::route('/'),
            'create' => Pages\CreateGlobalFilter::route('/create'),
            'edit'   => Pages\EditGlobalFilter::route('/{record}/edit'),
        ];
    }
}
