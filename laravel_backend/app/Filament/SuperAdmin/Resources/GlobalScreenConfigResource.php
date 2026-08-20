<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource\Pages;
use App\Models\ScreenConfig;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalScreenConfigResource extends Resource
{
    protected static ?string $model = ScreenConfig::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-tv'; }
    public static function getNavigationGroup(): string { return 'Konten & Event'; }
    public static function getNavigationSort(): int { return 6; }
    public static function getModelLabel(): string { return 'Screen Config'; }
    public static function getPluralModelLabel(): string { return 'Semua Screen Config'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Layar & Alokasi Cafe')->schema([
                Select::make('event_id')
                    ->label('Event / Cafe')
                    ->relationship('event', 'name')
                    ->searchable()
                    ->preload()
                    ->required(),
                Select::make('screen_type')
                    ->label('Tipe Layar')
                    ->options([
                        'welcome'  => '👋 Layar Selamat Datang / Awal',
                        'tutorial' => '📖 Layar Petunjuk / Tutorial',
                        'payment'  => '💳 Layar Pembayaran QRIS',
                        'result'   => '🎉 Layar Hasil & Download QR',
                    ])
                    ->required(),
                Select::make('status')
                    ->label('Status')
                    ->options([
                        'active'   => 'Active',
                        'inactive' => 'Inactive',
                    ])
                    ->default('active')
                    ->required(),
                TextInput::make('version')
                    ->label('Versi Config')
                    ->default(1)
                    ->numeric()
                    ->required(),
                TextInput::make('title')
                    ->label('Judul Layar')
                    ->maxLength(255),
                Textarea::make('description')
                    ->label('Deskripsi / Teks Petunjuk')
                    ->columnSpanFull(),
                TextInput::make('button_text')
                    ->label('Teks Tombol Aksi')
                    ->placeholder('Contoh: Mulai Sesi, Lanjutkan, Cetak Ulang'),
                FileUpload::make('background_url')
                    ->label('Gambar Background Kustom (Opsional)')
                    ->image()
                    ->directory('screens'),
            ])->columns(2),

            Section::make('Langkah-langkah Tutorial (Khusus Layar Tutorial)')
                ->visible(fn ($get) => $get('screen_type') === 'tutorial')
                ->schema([
                    Repeater::make('tutorialSteps')
                        ->relationship('tutorialSteps')
                        ->schema([
                            TextInput::make('title')->label('Judul Langkah')->required(),
                            Textarea::make('description')->label('Keterangan')->required(),
                            FileUpload::make('image_url')->label('Ilustrasi')->image()->directory('tutorials'),
                            TextInput::make('sort_order')->label('Urutan')->numeric()->default(1),
                        ])
                        ->orderColumn('sort_order')
                        ->collapsible(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('screen_type')->label('Tipe Layar')->badge()->color('primary')->sortable(),
                TextColumn::make('event.cafe.name')->label('Cafe')->badge()->color('gray')->searchable()->sortable(),
                TextColumn::make('event.name')->label('Event')->placeholder('Main Booth')->sortable(),
                TextColumn::make('title')->label('Judul')->searchable()->limit(30),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => $state === 'active' ? 'success' : 'danger'),
                TextColumn::make('version')->label('v')->prefix('v')->sortable(),
            ])
            ->filters([
                SelectFilter::make('event.cafe_id')
                    ->label('Filter Cafe')
                    ->relationship('event.cafe', 'name'),
                SelectFilter::make('screen_type')
                    ->options([
                        'welcome'  => 'Welcome',
                        'tutorial' => 'Tutorial',
                        'payment'  => 'Payment',
                        'result'   => 'Result',
                    ]),
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
            'index'  => Pages\ListGlobalScreenConfigs::route('/'),
            'create' => Pages\CreateGlobalScreenConfig::route('/create'),
            'edit'   => Pages\EditGlobalScreenConfig::route('/{record}/edit'),
        ];
    }
}
