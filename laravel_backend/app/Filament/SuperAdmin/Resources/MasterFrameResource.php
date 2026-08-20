<?php

namespace App\Filament\SuperAdmin\Resources;

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
use Filament\Forms\Components\Hidden;
use Filament\Forms\Components\KeyValue;
use Filament\Forms\Components\Repeater;
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
                    Select::make('layout_type')
                        ->label('Tipe Layout Cetak')
                        ->options([
                            'single'   => 'Single Strip / Standar (1 Kolom)',
                            'double_6' => 'Double Strip 6 Foto (2 Kolom: Kiri 3, Kanan 3 — Ambil 3 Pose)',
                            'double_8' => 'Double Strip 8 Foto (2 Kolom: Kiri 4, Kanan 4 — Ambil 4 Pose)',
                        ])
                        ->default('single')
                        ->live()
                        ->afterStateUpdated(function ($state, callable $set) {
                            if ($state === 'double_6') {
                                $set('pose_count', 3);
                            } elseif ($state === 'double_8') {
                                $set('pose_count', 4);
                            }
                        })
                        ->afterStateHydrated(function ($component, $state, $record) {
                            if ($record) {
                                $type = $record->layout_config['layout_type'] ?? $record->layout_type ?? 'single';
                                $component->state($type);
                            }
                        })
                        ->required(),

                    Select::make('right_column_order')
                        ->label('Urutan Pose Kolom Kanan')
                        ->options([
                            'scrambled_1' => 'Pose 3, Pose 1, Pose 2 (Acak 1)',
                            'scrambled_2' => 'Pose 2, Pose 3, Pose 1 (Acak 2)',
                            'reversed'    => 'Pose 3, Pose 2, Pose 1 (Terbalik)',
                            'identical'   => 'Pose 1, Pose 2, Pose 3 (Identik / Kembar)',
                        ])
                        ->default('scrambled_1')
                        ->visible(fn ($get) => in_array($get('layout_type'), ['double_6', 'double_8']))
                        ->afterStateHydrated(function ($component, $state, $record) {
                            if ($record && !empty($record->layout_config['right_column_order_key'])) {
                                $component->state($record->layout_config['right_column_order_key']);
                            }
                        }),

                    TextInput::make('pose_count')
                        ->label('Jumlah Pose Foto')
                        ->numeric()
                        ->default(4)
                        ->required(),
                    Toggle::make('is_active')
                        ->label('Status Aktif')
                        ->default(true),
                ])->columns(2),

            Section::make('File Aset & Layout Koordinat')
                ->schema([
                    Toggle::make('use_ai_detection')
                        ->label('Mode AI (Auto-Detect Layout & Auto-Punch Transparan)')
                        ->helperText('Aktifkan agar AI otomatis mendeteksi posisi kotak foto dan melubangi transparansi saat disimpan.')
                        ->default(fn () => \App\Models\AiSetting::isAiAvailable())
                        ->visible(fn () => \App\Models\AiSetting::isAiAvailable())
                        ->columnSpanFull(),

                    FileUpload::make('asset_url')
                        ->label('File Desain Frame (PNG Transparan / Gambar Frame)')
                        ->image()
                        ->directory('frames')
                        ->disk('public')
                        ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
                        ->helperText(function (callable $get) {
                            $isAiAllowed = \App\Models\AiSetting::isAiAvailable();
                            if (!$isAiAllowed) {
                                return '📁 File frame akan diproses sesuai format dan tipe layout yang Anda pilih di atas.';
                            }
                            $isAi = $get('use_ai_detection') ?? true;
                            if ($isAi) {
                                return '✨ Mode AI Aktif: Sistem AI akan otomatis mendeteksi posisi slot & melubangi kotak foto saat disimpan.';
                            }
                            return '📁 Mode Frame Standar: File frame akan diunggah original tanpa modifikasi AI.';
                        })
                        ->columnSpanFull(),
                    Textarea::make('description')
                        ->label('Deskripsi Desain')
                        ->rows(3)
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
                TextEntry::make('layout_type')->label('Tipe Layout')->badge()
                    ->formatStateUsing(fn ($state) => match($state) {
                        'double_6' => 'Double Strip 6 Foto',
                        'double_8' => 'Double Strip 8 Foto',
                        default    => 'Single Strip',
                    }),
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
                TextColumn::make('pose_count')
                    ->label('Pose')
                    ->suffix(' Pose')
                    ->badge()
                    ->color('info')
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
