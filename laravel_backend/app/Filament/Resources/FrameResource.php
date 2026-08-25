<?php

namespace App\Filament\Resources;

use App\Filament\Forms\Components\FrameCanvasEditor;
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
            Section::make('Informasi Frame')->schema([
                Select::make('event_id')
                    ->label('Event')
                    ->relationship(
                        name: 'event',
                        titleAttribute: 'name',
                        modifyQueryUsing: fn ($query) => auth()->user()?->cafe_id ? $query->where('cafe_id', auth()->user()->cafe_id)->orWhereNull('cafe_id') : $query
                    )
                    ->searchable()
                    ->preload(),

                TextInput::make('name')
                    ->label('Nama Frame')
                    ->required()
                    ->maxLength(255),

                FileUpload::make('asset_url')
                    ->label('File Desain Frame (PNG Transparan / Gambar Frame)')
                    ->helperText('Upload desain frame Anda. Jika belum berlubang transparan, sistem akan melubanginya otomatis sesuai letak kotak foto di editor visual di bawah.')
                    ->image()
                    ->imagePreviewHeight('280')
                    ->disk('public')
                    ->directory('frames')
                    ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
                    ->maxSize(51200)
                    ->live()
                    ->columnSpanFull()
                    ->required(),

                Toggle::make('active')
                    ->label('Status Aktif')
                    ->default(true),
            ])->columns(2),

            Section::make('Visual Frame Builder (Atur Posisi, Ukuran & Urutan Pose Foto)')->schema([
                FrameCanvasEditor::make('layout_config')
                    ->label('')
                    ->imageField('asset_url')
                    ->columnSpanFull(),
            ]),
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
                        TextEntry::make('event.name')->label('Event')->default('Main Booth'),
                        TextEntry::make('pose_count')->label('Jumlah Pose')->suffix(' Pose'),
                        TextEntry::make('layout_type_display')
                            ->label('Layout')
                            ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                                $record->layout_config ?? [],
                                $record->pose_count
                            ))
                            ->badge()
                            ->color('info'),
                        IconEntry::make('active')->label('Aktif')->boolean(),
                        TextEntry::make('created_at')->label('Dibuat')->dateTime('d M Y H:i'),
                    ])->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('asset_url')
                    ->label('Preview')
                    ->disk('public')
                    ->height(60)
                    ->square(),

                TextColumn::make('name')
                    ->label('Nama Frame')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                TextColumn::make('event.name')
                    ->label('Event')
                    ->default('Main Booth')
                    ->sortable()
                    ->badge()
                    ->color('primary'),

                TextColumn::make('layout_display')
                    ->label('Layout Slot')
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    ))
                    ->badge()
                    ->color('info'),

                TextColumn::make('pose_count')
                    ->label('Pose Kamera')
                    ->suffix(' Pose')
                    ->sortable(),

                IconColumn::make('active')
                    ->label('Aktif')
                    ->boolean()
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Dibuat')
                    ->dateTime('d M Y')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('active')
                    ->label('Status Aktif'),
            ])
            ->actions([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListFrames::route('/'),
            'create' => Pages\CreateFrame::route('/create'),
            'edit'   => Pages\EditFrame::route('/{record}/edit'),
        ];
    }
}
