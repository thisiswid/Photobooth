<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\Forms\Components\FrameCanvasEditor;
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

                FileUpload::make('asset_url')
                    ->label('File PNG Frame')
                    ->image()
                    ->directory('frames')
                    ->disk('public')
                    ->live()
                    ->helperText('Upload desain frame. Jika belum berlubang transparan, sistem akan melubanginya otomatis sesuai kotak di editor visual di bawah.')
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
        return $schema->components([
            Section::make('Rincian Frame')->schema([
                TextEntry::make('name')->label('Nama Frame')->weight('bold'),
                TextEntry::make('event.cafe.name')->label('Lokasi Cafe')->badge()->color('primary'),
                TextEntry::make('event.name')->label('Event'),
                TextEntry::make('layout_display')->label('Layout')->badge()
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    )),
                TextEntry::make('pose_count')->label('Jumlah Pose')->suffix(' Pose'),
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
                TextColumn::make('pose_count')->label('Pose')->suffix(' Poses')->sortable(),
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
