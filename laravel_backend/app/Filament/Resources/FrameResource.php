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
use Filament\Forms\Components\Hidden;
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

            TextInput::make('slot_count')
                ->label('Jumlah Kotak Foto')
                ->numeric()
                ->default(4)
                ->minValue(1)
                ->maxValue(8)
                ->required()
                ->live()
                ->helperText('Berapa banyak kotak foto pada hasil cetak (1–8 kotak).')
                ->afterStateUpdated(function ($state, callable $set, callable $get) {
                    $slots = max(1, min(8, (int) ($state ?: 4)));
                    $cols  = max(1, min(3, (int) ($get('columns') ?: 1)));
                    $set('pose_count', (int) ceil($slots / $cols));
                })
                ->afterStateHydrated(function ($component, $state, $record) {
                    if ($record && !empty($record->layout_config['slot_count'])) {
                        $component->state((int) $record->layout_config['slot_count']);
                    }
                }),

            Select::make('columns')
                ->label('Susunan Kolom')
                ->options([
                    1 => '1 Kolom — Strip Vertikal',
                    2 => '2 Kolom — Foto Kembar Kiri-Kanan',
                    3 => '3 Kolom',
                ])
                ->default(1)
                ->live()
                ->required()
                ->helperText('Jumlah baris dihitung otomatis: kotak ÷ kolom.')
                ->afterStateUpdated(function ($state, callable $set, callable $get) {
                    $slots = max(1, min(8, (int) ($get('slot_count') ?: 4)));
                    $cols  = max(1, min(3, (int) ($state ?: 1)));
                    $set('pose_count', (int) ceil($slots / $cols));
                })
                ->afterStateHydrated(function ($component, $state, $record) {
                    if (!$record) {
                        return;
                    }
                    $cfg = $record->layout_config ?? [];
                    if (!empty($cfg['columns'])) {
                        $component->state((int) $cfg['columns']);
                    } elseif (in_array($cfg['layout_type'] ?? null, ['double_6', 'double_8'])) {
                        $component->state(2);
                    }
                }),

            Select::make('slot_aspect')
                ->label('Bentuk Kotak Foto')
                ->options([
                    'portrait'  => 'Persegi Panjang Tegak / Potret (3:4)',
                    'square'    => 'Persegi (1:1)',
                    'landscape' => 'Persegi Panjang Tidur / Lanskap (4:3)',
                ])
                ->default('portrait')
                ->required()
                ->afterStateHydrated(function ($component, $state, $record) {
                    if ($record && !empty($record->layout_config['slot_aspect'])) {
                        $component->state($record->layout_config['slot_aspect']);
                    }
                }),

            TextInput::make('pose_count')
                ->label('Jumlah Pose Kamera (Otomatis)')
                ->numeric()
                ->default(4)
                ->disabled()
                ->dehydrated(false)
                ->helperText('Dihitung otomatis dari jumlah kotak & kolom. 2/3 kolom = foto kembar per baris.'),

            Select::make('right_column_order')
                ->label('Urutan Pose Kolom Kanan')
                ->options([
                    'identical'   => 'Identik / Kembar',
                    'scrambled_1' => 'Acak 1 (digeser)',
                    'scrambled_2' => 'Acak 2 (digeser 2)',
                    'reversed'    => 'Terbalik',
                ])
                ->default('identical')
                ->visible(fn ($get) => (int) ($get('columns') ?? 1) >= 2)
                ->afterStateHydrated(function ($component, $state, $record) {
                    if ($record && !empty($record->layout_config['right_column_order_key'])) {
                        $component->state($record->layout_config['right_column_order_key']);
                    }
                }),

            Toggle::make('use_ai_detection')
                ->label('Mode AI (Auto-Detect Layout & Auto-Punch Transparan)')
                ->helperText('Aktifkan agar AI otomatis mendeteksi posisi kotak foto dan melubangi transparansi saat disimpan. Jika mati, sistem memakai pengaturan kotak di atas.')
                ->default(false)
                ->visible(fn () => \App\Models\AiSetting::isAiAvailable(auth()->user()?->cafe_id)),

            FileUpload::make('asset_url')
                ->label('File Frame Template (PNG Transparan / Gambar Frame)')
                ->helperText(function (callable $get) {
                    $slots = max(1, min(8, (int) ($get('slot_count') ?: 4)));
                    $cols  = max(1, min(3, (int) ($get('columns') ?: 1)));
                    $poses = (int) ceil($slots / $cols);
                    $dimGuide = $cols >= 2
                        ? "📐 Rekomendasi Kanvas: 1200×1800 px (300 DPI 4R). Layout: {$slots} kotak, {$cols} kolom, {$poses} pose."
                        : "📐 Rekomendasi Kanvas: 600×1800 px (300 DPI 2x6\"). Layout: {$slots} kotak, 1 kolom, {$poses} pose.";

                    $isAiAllowed = \App\Models\AiSetting::isAiAvailable(auth()->user()?->cafe_id);
                    if (!$isAiAllowed) {
                        return "$dimGuide\n📁 Mode Manual: PNG transparan dibaca lubangnya otomatis; PNG biasa dilubangi sesuai pengaturan kotak di atas.";
                    }
                    $isAi = $get('use_ai_detection') ?? false;
                    if ($isAi) {
                        return "$dimGuide\n✨ Mode AI Aktif: Sistem AI akan otomatis mendeteksi posisi kotak foto & melubangi transparansi saat disimpan.";
                    }
                    return "$dimGuide\n📁 Mode Manual: PNG transparan dibaca lubangnya otomatis; PNG biasa dilubangi sesuai pengaturan kotak di atas.";
                })
                ->image()
                ->imagePreviewHeight('300')
                ->disk('public')
                ->directory('frames')
                ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
                ->maxSize(51200)
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
                        TextEntry::make('event.name')->label('Event')->default('Main Booth'),
                        TextEntry::make('pose_count')->label('Jumlah Pose'),
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
                    ])
                    ->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('asset_url')
                    ->label('Preview')
                    ->height(75)
                    ->width(55)
                    ->disk('public')
                    ->extraImgAttributes([
                        'style' => 'object-fit: contain; background: repeating-conic-gradient(#e0e0e0 0% 25%, #fff 0% 50%) 0 0 / 10px 10px; border-radius: 4px;',
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

                TextColumn::make('pose_info')
                    ->label('Layout')
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    ))
                    ->badge()
                    ->color('success'),

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

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where(function ($q) use ($cafeId) {
                $q->whereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId))
                  ->orWhereHas('event', fn ($eq) => $eq->whereNull('cafe_id'))
                  ->orWhereNull('event_id');
            });
        }
        return $query;
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
