<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\Forms\Components\FrameCanvasEditor;
use App\Filament\SuperAdmin\Resources\MasterFrameResource\Pages;
use App\Models\Cafe;
use App\Models\MasterFrame;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Components\IconEntry;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class MasterFrameResource extends Resource
{
    protected static ?string $model = MasterFrame::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-sparkles'; }
    public static function getNavigationGroup(): string { return 'Global Catalog'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Master Frame Template'; }
    public static function getPluralModelLabel(): string { return 'Master Frame Library'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Master Template')
                ->schema([
                    TextInput::make('name')
                        ->label('Nama Template')
                        ->required()
                        ->maxLength(255)
                        ->placeholder('Contoh: Vintage Classic Photo Strip (4 Poses)'),

                    Select::make('category')
                        ->label('Kategori')
                        ->options([
                            'General'         => 'General / Standar',
                            'Coffee & Cafe'   => 'Coffee & Cafe',
                            'Minimalist'      => 'Minimalist / Korean Aesthetic',
                            'Vintage'         => 'Vintage / Retro',
                            'Wedding & Party' => 'Wedding & Celebration',
                            'Holiday'         => 'Holiday & Seasonal',
                        ])
                        ->default('General')
                        ->required(),

                    FileUpload::make('asset_url')
                        ->label('File Desain Frame (PNG Transparan / Gambar Frame)')
                        ->image()
                        ->directory('frames')
                        ->disk('public')
                        ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
                        ->maxSize(51200)
                        ->live()
                        ->helperText('Upload gambar template. Jika belum berlubang transparan, sistem akan melubanginya otomatis sesuai kotak di editor visual di bawah.')
                        ->columnSpanFull()
                        ->required(),

                    Textarea::make('description')
                        ->label('Deskripsi Desain')
                        ->rows(2)
                        ->columnSpanFull(),

                    Toggle::make('is_active')
                        ->label('Status Aktif')
                        ->default(true),
                ])->columns(2),

            Section::make('Visual Frame Builder (Atur Posisi, Ukuran & Urutan Pose Foto)')
                ->schema([
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
            Section::make('Preview Desain Frame Template')->schema([
                ImageEntry::make('asset_url')
                    ->label('')
                    ->disk('public')
                    ->extraImgAttributes([
                        'style' => 'max-height: 350px; object-fit: contain; background: repeating-conic-gradient(#e0e0e0 0% 25%, #fff 0% 50%) 0 0 / 20px 20px; border-radius: 8px; padding: 8px;',
                    ])
                    ->columnSpanFull(),
            ]),

            Section::make('Informasi Template')->schema([
                TextEntry::make('name')->label('Nama Frame')->weight('bold'),
                TextEntry::make('category')->label('Kategori')->badge()->color('primary'),
                TextEntry::make('layout_display')->label('Layout')->badge()
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    )),
                TextEntry::make('pose_count')->label('Jumlah Pose')->suffix(' Pose'),
                TextEntry::make('usage_count')->label('Digunakan di Cafe')->suffix(' Cafe')->badge()->color('success'),
                IconEntry::make('is_active')->label('Status Aktif')->boolean(),
                TextEntry::make('description')->label('Deskripsi Desain')->default('-')->columnSpanFull(),
            ])->columns(3),
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
                TextColumn::make('category')
                    ->label('Kategori')
                    ->badge()
                    ->color('primary')
                    ->sortable(),
                TextColumn::make('layout_display')
                    ->label('Layout Slot')
                    ->state(fn ($record) => \App\Services\FrameSlotDetector::describeGridLayout(
                        $record->layout_config ?? [],
                        $record->pose_count
                    ))
                    ->badge()
                    ->color('info'),
                TextColumn::make('pose_count')
                    ->label('Pose')
                    ->suffix(' Pose')
                    ->badge()
                    ->color('warning')
                    ->sortable(),
                TextColumn::make('usage_count')
                    ->label('Digunakan')
                    ->suffix(' Cafe')
                    ->badge()
                    ->color('success')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('Aktif')
                    ->boolean(),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->options([
                        'General'         => 'General',
                        'Coffee & Cafe'   => 'Coffee & Cafe',
                        'Minimalist'      => 'Minimalist',
                        'Vintage'         => 'Vintage',
                        'Wedding & Party' => 'Wedding & Party',
                        'Holiday'         => 'Holiday',
                    ]),
                TernaryFilter::make('is_active')->label('Status Aktif'),
            ])
            ->actions([
                Action::make('push_to_cafe')
                    ->label('Bagikan ke Cafe')
                    ->icon('heroicon-o-paper-airplane')
                    ->color('success')
                    ->form([
                        Select::make('target')
                            ->label('Target Distribusi')
                            ->options([
                                'all'      => '🚀 Bagikan ke SEMUA Cafe Aktif (Otomatis lewati yang sudah punya)',
                                'specific' => '🏢 Pilih Cafe Tertentu',
                            ])
                            ->default('specific')
                            ->live()
                            ->required(),
                        Select::make('cafe_ids')
                            ->label('Pilih Cafe')
                            ->multiple()
                            ->options(function (MasterFrame $record) {
                                $installedCafeIds = $record->getInstalledCafeIds();
                                return Cafe::where('status', 'active')
                                    ->get()
                                    ->mapWithKeys(function ($cafe) use ($installedCafeIds) {
                                        $isInstalled = in_array($cafe->id, $installedCafeIds);
                                        $label = $isInstalled
                                            ? "{$cafe->name} (✓ Sudah Memiliki Frame Ini)"
                                             : $cafe->name;
                                        return [$cafe->id => $label];
                                    });
                            })
                            ->disableOptionWhen(function (string $value, MasterFrame $record) {
                                return in_array((int)$value, $record->getInstalledCafeIds());
                            })
                            ->searchable()
                            ->helperText('Cafe yang sudah memiliki frame ini ditandai "(✓ Sudah Memiliki Frame Ini)" dan tidak dapat dipilih lagi.')
                            ->visible(fn (callable $get) => $get('target') === 'specific')
                            ->required(fn (callable $get) => $get('target') === 'specific'),
                    ])
                    ->action(function (MasterFrame $record, array $data) {
                        if ($data['target'] === 'all') {
                            $cafes = Cafe::where('status', 'active')->get();
                            $newlyAdded = 0;
                            $skipped = 0;

                            foreach ($cafes as $c) {
                                $res = $record->pushToCafe($c);
                                if ($res !== null) {
                                    $newlyAdded++;
                                } else {
                                    $skipped++;
                                }
                            }

                            if ($newlyAdded > 0 && $skipped > 0) {
                                Notification::make()
                                    ->title("Frame berhasil dibagikan ke {$newlyAdded} cafe baru!")
                                    ->body("{$skipped} cafe dilewati karena sudah memiliki frame ini.")
                                    ->success()
                                    ->send();
                            } elseif ($newlyAdded > 0) {
                                Notification::make()
                                    ->title("Frame berhasil dibagikan ke {$newlyAdded} cafe!")
                                    ->success()
                                    ->send();
                            } else {
                                Notification::make()
                                    ->title("Semua cafe aktif ({$skipped} cafe) sudah memiliki frame ini.")
                                    ->warning()
                                    ->send();
                            }
                        } else {
                            $cafeIds = (array) ($data['cafe_ids'] ?? []);
                            $newlyAdded = 0;
                            $skipped = 0;
                            $names = [];

                            foreach ($cafeIds as $cafeId) {
                                $cafe = Cafe::find($cafeId);
                                if ($cafe) {
                                    $res = $record->pushToCafe($cafe);
                                    if ($res !== null) {
                                        $newlyAdded++;
                                        $names[] = $cafe->name;
                                    } else {
                                        $skipped++;
                                    }
                                }
                            }

                            if ($newlyAdded > 0) {
                                $cafeSummary = implode(', ', array_slice($names, 0, 3));
                                if ($newlyAdded > 3) {
                                    $cafeSummary .= ' dan ' . ($newlyAdded - 3) . ' lainnya';
                                }
                                $notif = Notification::make()
                                    ->title("Frame berhasil ditambahkan ke {$newlyAdded} cafe ({$cafeSummary})!")
                                    ->success();
                                if ($skipped > 0) {
                                    $notif->body("{$skipped} cafe dilewati karena sudah memiliki frame ini.");
                                }
                                $notif->send();
                            } else {
                                Notification::make()
                                    ->title("Tidak ada cafe baru yang ditambahkan karena sudah memiliki frame ini sebelumnya.")
                                    ->warning()
                                    ->send();
                            }
                        }
                    }),
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListMasterFrames::route('/'),
            'create' => Pages\CreateMasterFrame::route('/create'),
            'edit'   => Pages\EditMasterFrame::route('/{record}/edit'),
        ];
    }
}
