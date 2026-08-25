<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;
use App\Models\Frame;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalFrameResource extends Resource
{
    protected static ?string $model = Frame::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-photo'; }
    public static function getNavigationGroup(): string { return 'Konten & Event'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Frame Cafe'; }
    public static function getPluralModelLabel(): string { return 'Semua Frame Cafe'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Frame & Alokasi Cafe')->schema([
                Select::make('event_id')
                    ->label('Event / Cafe')
                    ->relationship('event', 'name')
                    ->searchable()
                    ->preload()
                    ->required(),
                TextInput::make('name')
                    ->label('Nama Frame')
                    ->required()
                    ->maxLength(255),
                Select::make('master_frame_id')
                    ->label('Sumber Template Master (Opsional)')
                    ->relationship('masterFrame', 'name')
                    ->searchable()
                    ->preload(),
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
                    ->helperText('Dihitung otomatis dari jumlah kotak & kolom.'),
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
                    ->visible(fn () => \App\Models\AiSetting::isAiAvailable()),
                FileUpload::make('asset_url')
                    ->label('File PNG Frame')
                    ->image()
                    ->directory('frames')
                    ->columnSpanFull()
                    ->required(),
                Toggle::make('active')
                    ->label('Status Aktif')
                    ->default(true),
            ])->columns(2),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Frame')->schema([
                TextEntry::make('name')->label('Nama Frame')->weight('bold'),
                TextEntry::make('event.cafe.name')->label('Lokasi Cafe')->badge()->color('primary'),
                TextEntry::make('event.name')->label('Event'),
                TextEntry::make('pose_count')->label('Jumlah Pose')->suffix(' Pose'),
                TextEntry::make('layout_display')->label('Layout')->badge()
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    )),
                TextEntry::make('masterFrame.name')->label('Template Master')->placeholder('Kustom Cafe'),
                TextEntry::make('sessions_count')->label('Total Penggunaan')
                    ->state(fn ($record) => $record->sessions()->count() . ' Kali'),
            ])->columns(3),

            Section::make('Preview File Frame')->schema([
                ImageEntry::make('asset_url')->label('Desain PNG')->disk('public'),
            ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('asset_url')->label('Preview')->disk('public')->square(),
                TextColumn::make('name')->label('Nama Frame')->searchable()->sortable()->weight('bold'),
                TextColumn::make('event.cafe.name')->label('Cafe')->badge()->color('primary')->searchable()->sortable(),
                TextColumn::make('event.name')->label('Event')->placeholder('Main Booth')->sortable(),
                TextColumn::make('layout_display')
                    ->label('Layout')
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    ))
                    ->badge()
                    ->color('info'),
                TextColumn::make('masterFrame.name')->label('Master Origin')->placeholder('Custom Upload')->limit(20),
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
            'index'  => Pages\ListGlobalFrames::route('/'),
            'create' => Pages\CreateGlobalFrame::route('/create'),
            'edit'   => Pages\EditGlobalFrame::route('/{record}/edit'),
        ];
    }
}
