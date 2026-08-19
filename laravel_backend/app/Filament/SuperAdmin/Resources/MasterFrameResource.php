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
                        ->helperText('Aktifkan agar AI otomatis mendeteksi posisi kotak foto dan melubangi transparansi saat upload. Matikan jika ingin menggunakan file frame original tanpa perubahan AI.')
                        ->default(true)
                        ->live()
                        ->afterStateUpdated(function ($state, callable $set, callable $get) {
                            if (!$state) {
                                $set('ai_status_text', '<span style="color:#64748b; font-weight:600;">ℹ️ Mode AI Dinonaktifkan:</span> File frame akan diunggah sesuai aslinya tanpa deteksi/pelubangan AI.');
                            } else {
                                $file = $get('asset_url');
                                if ($file) {
                                    $analysis = \App\Services\FrameSlotDetector::analyze($file, autoPunchTransparency: true);
                                    if ($analysis['success']) {
                                        $set('layout_type', $analysis['layout_type']);
                                        $set('pose_count', $analysis['pose_count']);
                                        $set('ai_status_text', '<span style="color:#10b981; font-weight:600;">✨ Mode AI Aktif:</span> ' . e($analysis['layout_label']));
                                    }
                                } else {
                                    $set('ai_status_text', null);
                                }
                            }
                        })
                        ->columnSpanFull(),

                    Hidden::make('ai_status_text')->dehydrated(false),

                    FileUpload::make('asset_url')
                        ->label('File Desain Frame (PNG Transparan / Gambar Frame)')
                        ->image()
                        ->directory('frames')
                        ->disk('public')
                        ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
                        ->helperText(function (callable $get) {
                            $status = $get('ai_status_text');
                            if ($status) {
                                return new \Illuminate\Support\HtmlString($status);
                            }
                            $isAi = $get('use_ai_detection') ?? true;
                            if ($isAi) {
                                return '✨ Mode AI Aktif: Upload file frame (PNG/JPG). Sistem AI akan otomatis mendeteksi layout & melubangi kotak foto.';
                            }
                            return '📁 Mode AI Nonaktif: File frame akan diunggah original tanpa modifikasi AI.';
                        })
                        ->live()
                        ->afterStateUpdated(function ($state, callable $set, callable $get) {
                            if (!$state) {
                                $set('ai_status_text', null);
                                return;
                            }
                            $isAi = $get('use_ai_detection') ?? true;
                            if (!$isAi) {
                                $set('ai_status_text', '<span style="color:#64748b; font-weight:600;">📁 Mode AI Nonaktif:</span> Frame diunggah tanpa analisis AI & pelubangan otomatis.');
                                return;
                            }
                            $analysis = \App\Services\FrameSlotDetector::analyze($state, autoPunchTransparency: true);
                            if ($analysis['success']) {
                                $set('layout_type', $analysis['layout_type']);
                                $set('pose_count', $analysis['pose_count']);
                                
                                // Buat teks status inline dengan icon line
                                if (!empty($analysis['ai_feedback']) && !$analysis['ai_feedback']['success'] && !empty($analysis['ai_feedback']['attempted'])) {
                                    $statusType = $analysis['ai_feedback']['status'] ?? 'warning';
                                    if ($statusType === 'danger') {
                                        $statusHtml = '<span style="color:#ef4444; font-weight:600;">❌ ' . e($analysis['ai_feedback']['title']) . ':</span> ' . e($analysis['ai_feedback']['message']) . ' <span style="color:#64748b;">(Layout lokal: ' . e($analysis['layout_label']) . ')</span>';
                                    } else {
                                        $statusHtml = '<span style="color:#f59e0b; font-weight:600;">⚠️ ' . e($analysis['ai_feedback']['title']) . ':</span> ' . e($analysis['ai_feedback']['message']) . ' <span style="color:#64748b;">(Layout lokal: ' . e($analysis['layout_label']) . ')</span>';
                                    }
                                } elseif ($analysis['method'] === 'openagentic_ai_vision' || $analysis['method'] === 'gemini_ai_vision') {
                                    $aiName = ($analysis['method'] === 'openagentic_ai_vision') ? 'Claude Sonnet 4.6 (AI Vision)' : 'Gemini AI Vision';
                                    $punchInfo = !empty($analysis['punched']) ? ' • 🪄 <b>Kotak foto telah dibuat transparan</b>' : '';
                                    $statusHtml = '<span style="color:#10b981; font-weight:600;">✨ ' . $aiName . ':</span> ' . e($analysis['layout_label']) . ' (' . $analysis['pose_count'] . ' Pose)' . $punchInfo;
                                } elseif ($analysis['method'] === 'alpha_contour') {
                                    $statusHtml = '<span style="color:#3b82f6; font-weight:600;">🎨 Computer Vision:</span> ' . e($analysis['layout_label']) . ' (' . $analysis['pose_count'] . ' Pose) — ' . e($analysis['description']);
                                } else {
                                    $punchInfo = !empty($analysis['punched']) ? ' • 🪄 <b>Kotak foto dilubangi transparan</b>' : '';
                                    $statusHtml = '<span style="color:#6366f1; font-weight:600;">📐 Deteksi Rasio:</span> ' . e($analysis['layout_label']) . ' (' . $analysis['pose_count'] . ' Pose)' . $punchInfo;
                                }

                                $set('ai_status_text', $statusHtml);
                            } else {
                                $set('ai_status_text', '<span style="color:#ef4444; font-weight:600;">⚠️ Gagal Deteksi:</span> ' . e($analysis['message'] ?? 'Gambar tidak dapat dianalisis.'));
                            }
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
                                'all'      => '🚀 Bagikan ke SEMUA Cafe Aktif',
                                'specific' => '🏢 Pilih Cafe Tertentu',
                            ])
                            ->default('specific')
                            ->live()
                            ->required(),
                        Select::make('cafe_id')
                            ->label('Pilih Cafe')
                            ->options(Cafe::where('status', 'active')->pluck('name', 'id'))
                            ->searchable()
                            ->visible(fn (callable $get) => $get('target') === 'specific')
                            ->required(fn (callable $get) => $get('target') === 'specific'),
                    ])
                    ->action(function (MasterFrame $record, array $data) {
                        if ($data['target'] === 'all') {
                            $cafes = Cafe::where('status', 'active')->get();
                            foreach ($cafes as $c) {
                                $record->pushToCafe($c);
                            }
                            Notification::make()
                                ->title("Frame berhasil dibagikan ke {$cafes->count()} cafe!")
                                ->success()
                                ->send();
                        } else {
                            $cafe = Cafe::find($data['cafe_id']);
                            if ($cafe) {
                                $record->pushToCafe($cafe);
                                Notification::make()
                                    ->title("Frame berhasil ditambahkan ke {$cafe->name}!")
                                    ->success()
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
