<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalAiSettingResource\Pages;
use App\Models\AiSetting;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class GlobalAiSettingResource extends Resource
{
    protected static ?string $model = AiSetting::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-cpu-chip'; }
    public static function getNavigationGroup(): string { return 'Platform & Core Config'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Pengaturan AI Platform'; }
    public static function getPluralModelLabel(): string { return 'Pengaturan AI Platform'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Master Sakelar AI (Global AI Switch)')
                ->description('Kontrol utama aktivasi seluruh fitur kecerdasan buatan (AI) di sistem Photobooth')
                ->schema([
                    Toggle::make('is_enabled')
                        ->label('Status AI Platform (ON / OFF)')
                        ->helperText('Jika dinonaktifkan, semua fitur AI di Super Admin & Cafe Admin akan otomatis dimatikan dan beralih ke scanner manual/lokal')
                        ->default(true)
                        ->columnSpanFull(),
                ]),

            Section::make('Penyedia & Model AI (Provider & Model)')
                ->description('Tentukan engine AI yang digunakan untuk analisis gambar dan visual recognition')
                ->schema([
                    Select::make('provider')
                        ->label('AI Provider Engine')
                        ->options([
                            'gemini'      => 'Google Gemini Vision (Direkomendasikan - Cepat & Akurat)',
                            'openagentic' => 'OpenAgentic / Anthropic Claude',
                            'openai'      => 'OpenAI GPT-4o Vision',
                        ])
                        ->default('gemini')
                        ->required(),
                    TextInput::make('model')
                        ->label('Nama Model AI')
                        ->default('gemini-1.5-flash')
                        ->placeholder('Contoh: gemini-1.5-flash, gemini-1.5-pro, claude-3-5-sonnet')
                        ->required(),
                    TextInput::make('api_key')
                        ->label('API Key Kustom (Opsional)')
                        ->password()
                        ->revealable()
                        ->placeholder('Biarkan kosong untuk menggunakan API Key dari file server .env')
                        ->helperText('Jika diisi, API Key ini akan memprioritaskan konfigurasi di atas .env'),
                    TextInput::make('max_tokens')
                        ->label('Max Output Tokens')
                        ->numeric()
                        ->default(2048)
                        ->minValue(256)
                        ->maxValue(8192),
                ])->columns(2),

            Section::make('Modul Fitur AI yang Diizinkan (Feature Toggles)')
                ->description('Aktifkan atau nonaktifkan modul AI secara terpisah')
                ->schema([
                    Toggle::make('enable_frame_detection')
                        ->label('Deteksi Otomatis Lubang Slot Frame (AI Vision)')
                        ->helperText('AI menganalisis template frame dan otomatis memetakan koordinat kotak slot foto saat upload')
                        ->default(true),
                    Toggle::make('enable_auto_punch')
                        ->label('Auto-Punch Transparansi Lubang Foto')
                        ->helperText('AI otomatis melubangi bagian putih/solid pada frame yang belum bertipe PNG transparan')
                        ->default(true),
                    Toggle::make('enable_photo_enhancer')
                        ->label('AI Photo & Face Enhancement (Beta)')
                        ->helperText('Fitur peningkatan ketajaman dan pencahayaan otomatis pada hasil foto customer')
                        ->default(false),
                ])->columns(3),

            Section::make('Catatan Konfigurasi')
                ->schema([
                    Textarea::make('notes')
                        ->label('Catatan Super Admin')
                        ->placeholder('Catatan atau riwayat pembaruan konfigurasi AI...')
                        ->columnSpanFull(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                IconColumn::make('is_enabled')
                    ->label('Master AI')
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('danger'),
                TextColumn::make('provider')
                    ->label('Provider')
                    ->badge()
                    ->formatStateUsing(fn ($state) => strtoupper($state))
                    ->color(fn ($state) => match($state) {
                        'gemini'      => 'info',
                        'openagentic' => 'warning',
                        'openai'      => 'success',
                        default       => 'gray',
                    }),
                TextColumn::make('model')->label('Model AI')->searchable(),
                IconColumn::make('enable_frame_detection')->label('Slot Detector')->boolean(),
                IconColumn::make('enable_auto_punch')->label('Auto Punch')->boolean(),
                IconColumn::make('enable_photo_enhancer')->label('Photo Enhancer')->boolean(),
                TextColumn::make('updated_at')->label('Terakhir Diubah')->dateTime('d M Y H:i')->sortable(),
            ])
            ->actions([
                EditAction::make()->label('Ubah Pengaturan'),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalAiSettings::route('/'),
            'edit'  => Pages\EditGlobalAiSetting::route('/{record}/edit'),
        ];
    }
}
