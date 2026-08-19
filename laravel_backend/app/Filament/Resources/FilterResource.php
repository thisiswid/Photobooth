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
                ->relationship(
                    name: 'event',
                    titleAttribute: 'name',
                    modifyQueryUsing: fn ($query) => auth()->user()?->cafe_id ? $query->where('cafe_id', auth()->user()->cafe_id) : $query
                )
                ->searchable()->preload()->required(),
            TextInput::make('name')->label('Nama Filter')->required()->maxLength(255)
                ->placeholder('Contoh: Vintage Coffee, B&W Classic, dll'),
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
            FileUpload::make('thumbnail_url')->label('Thumbnail / Ikon (Opsional)')
                ->image()->directory('filters')->columnSpanFull(),
            TextInput::make('sort_order')->label('Urutan Tampilan')->numeric()->default(0),
            Toggle::make('active')->label('Aktifkan Filter')->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('thumbnail_url')
                    ->label('Thumbnail')
                    ->square()
                    ->disk('public')
                    ->defaultImageUrl(fn ($record) => null),
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

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->whereHas('event', fn ($q) => $q->where('cafe_id', $cafeId));
        }
        return $query;
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
