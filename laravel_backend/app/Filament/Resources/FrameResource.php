<?php

namespace App\Filament\Resources;

use App\Filament\Resources\FrameResource\Pages;
use App\Models\Frame;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Infolists\Components\ViewEntry;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class FrameResource extends Resource
{
    protected static ?string $model = Frame::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-photo'; }
    public static function getNavigationGroup(): string { return 'Konten'; }
    public static function getNavigationSort(): int { return 2; }
    public static function getModelLabel(): string { return 'Frame'; }
    public static function getPluralModelLabel(): string { return 'Frames'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('event_id')
                ->label('Event')
                ->relationship('event', 'name')
                ->searchable()
                ->preload(),

            TextInput::make('name')
                ->label('Nama Frame')
                ->required()
                ->maxLength(255),

            FileUpload::make('asset_url')
                ->label('File Frame')
                ->helperText('Upload PNG dengan background transparan. Resolusi minimal 1200×1800px.')
                ->image()
                ->imagePreviewHeight('300')
                ->disk('public')
                ->directory('frames')
                ->acceptedFileTypes(['image/png'])
                ->columnSpanFull(),

            Toggle::make('active')
                ->label('Aktif')
                ->default(true),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Preview Frame')
                    ->schema([
                        ViewEntry::make('asset_url')
                            ->label('')
                            ->view('filament.infolists.frame-preview')
                            ->columnSpanFull(),
                    ]),

                Section::make('Informasi')
                    ->schema([
                        TextEntry::make('name')->label('Nama Frame'),
                        TextEntry::make('event.name')->label('Event'),
                        IconEntry::make('active')->label('Aktif')->boolean(),
                        TextEntry::make('created_at')->label('Dibuat')->dateTime('d M Y H:i'),
                    ])
                    ->columns(4),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('asset_url')
                    ->label('Preview')
                    ->height(80)
                    ->width(60)
                    ->getStateUsing(fn ($record) => $record->asset_url
                        ? asset('storage/' . $record->asset_url)
                        : null
                    )
                    ->extraImgAttributes([
                        'style' => 'object-fit: contain; background: repeating-conic-gradient(#e0e0e0 0% 25%, #fff 0% 50%) 0 0 / 10px 10px;',
                    ]),

                TextColumn::make('name')
                    ->label('Nama Frame')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                TextColumn::make('event.name')
                    ->label('Event')
                    ->sortable()
                    ->badge()
                    ->color('info'),

                IconColumn::make('active')
                    ->label('Aktif')
                    ->boolean(),

                TextColumn::make('created_at')
                    ->label('Dibuat')
                    ->dateTime('d M Y')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                TernaryFilter::make('active')->label('Aktif'),
            ])
            ->actions([
                ViewAction::make()->label('Lihat'),
                EditAction::make()->label('Edit'),
                DeleteAction::make()->label('Hapus'),
            ])
            ->bulkActions([
                BulkActionGroup::make([DeleteBulkAction::make()]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListFrames::route('/'),
            'create' => Pages\CreateFrame::route('/create'),
            'view'   => Pages\ViewFrame::route('/{record}'),
            'edit'   => Pages\EditFrame::route('/{record}/edit'),
        ];
    }
}
