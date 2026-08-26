<?php

namespace App\Filament\Resources;

use App\Filament\Forms\Components\FramePencilEditor;
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
            Section::make('1. Informasi & Upload File Frame')->schema([
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

                Select::make('layout_type')
                    ->label('Tipe Layout Frame')
                    ->options([
                        'single'   => 'Single Strip (1 Kolom memanjang — 3 atau 4 Pose)',
                        'double_6' => 'Double Strip 6 Foto (2 Kolom — Ambil 3 Pose)',
                        'double_8' => 'Double Strip 8 Foto (2 Kolom — Ambil 4 Pose)',
                    ])
                    ->default('single')
                    ->live()
                    ->afterStateUpdated(function ($state, callable $set) {
                        if ($state === 'double_6') {
                            $set('pose_count', 3);
                        } elseif ($state === 'double_8') {
                            $set('pose_count', 4);
                        }
                    }),

                Select::make('right_column_order')
                    ->label('Urutan Pose Kolom Kanan')
                    ->options([
                        'scrambled_1' => 'Pose 3, Pose 1, Pose 2 (Acak 1)',
                        'scrambled_2' => 'Pose 2, Pose 3, Pose 1 (Acak 2)',
                        'reversed'    => 'Pose 3, Pose 2, Pose 1 (Terbalik)',
                        'identical'   => 'Pose 1, Pose 2, Pose 3 (Identik / Kembar)',
                    ])
                    ->default('scrambled_1')
                    ->visible(fn ($get) => in_array($get('layout_type'), ['double_6', 'double_8'])),

                TextInput::make('pose_count')
                    ->label('Jumlah Pose yang Diambil Kamera')
                    ->helperText('Berapa kali kamera akan menjepret foto (otomatis menyesuaikan jumlah lubang di kanvas).')
                    ->numeric()
                    ->default(4)
                    ->minValue(1)
                    ->maxValue(8)
                    ->required(),

                FileUpload::make('asset_url')
                    ->label('File Desain Frame (PNG Transparan / Gambar Frame)')
                    ->helperText('Upload desain frame Anda. Semua ornamen, stiker, dan tulisan di dalam frame akan 100% UTUH dan tidak akan terpotong!')
                    ->image()
                    ->imagePreviewHeight('200')
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

            Section::make('2. Kanvas Pensil Interaktif (Klik Warna untuk Melubangi Jadi Transparan)')->schema([
                FramePencilEditor::make('layout_config')
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
