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

            Select::make('layout_type')
                ->label('Tipe Layout Frame')
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
                    if ($record && !empty($record->layout_config['layout_type'])) {
                        $component->state($record->layout_config['layout_type']);
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
                ->visible(fn ($get) => in_array($get('layout_type'), ['double_6', 'double_8']))
                ->afterStateHydrated(function ($component, $state, $record) {
                    if ($record && !empty($record->layout_config['right_column_order_key'])) {
                        $component->state($record->layout_config['right_column_order_key']);
                    }
                }),

            TextInput::make('pose_count')
                ->label('Jumlah Pose yang Diambil Kamera')
                ->helperText('Berapa kali kamera akan menjepret foto untuk frame ini.')
                ->numeric()
                ->default(4)
                ->minValue(1)
                ->maxValue(8)
                ->required(),

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
                }),

            Hidden::make('ai_status_text')->dehydrated(false),

            FileUpload::make('asset_url')
                ->label('File Frame Template (PNG Transparan / Gambar Frame)')
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
                ->image()
                ->imagePreviewHeight('300')
                ->disk('public')
                ->directory('frames')
                ->acceptedFileTypes(['image/png', 'image/jpeg', 'image/webp'])
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
                            ->label('Tipe Layout')
                            ->state(fn ($record) => match($record->layout_config['layout_type'] ?? 'single') {
                                'double_6' => 'Double Strip 6 Foto (2 Kolom × 3)',
                                'double_8' => 'Double Strip 8 Foto (2 Kolom × 4)',
                                default    => 'Single Strip',
                            })
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
                    ->label('Tipe & Pose')
                    ->state(fn ($record) => match($record->layout_config['layout_type'] ?? 'single') {
                        'double_6' => '3 Pose (6 Slot)',
                        'double_8' => '4 Pose (8 Slot)',
                        default    => "{$record->pose_count} Pose",
                    })
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
