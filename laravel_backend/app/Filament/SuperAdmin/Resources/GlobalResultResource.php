<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalResultResource\Pages;
use App\Models\Result;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class GlobalResultResource extends Resource
{
    protected static ?string $model = Result::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-qr-code'; }
    public static function getNavigationGroup(): string { return 'Operasional Global'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Hasil Foto'; }
    public static function getPluralModelLabel(): string { return 'Semua Hasil Foto'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Hasil & Akses Download')->schema([
                TextEntry::make('session.id')->label('ID Sesi'),
                TextEntry::make('session.cafe.name')->label('Lokasi Cafe')->badge()->color('primary')->placeholder('-'),
                TextEntry::make('session.event.name')->label('Event')->placeholder('-'),
                TextEntry::make('session.frame.name')->label('Frame Terpilih')->placeholder('-'),
                TextEntry::make('session.filter.name')->label('Filter Terpilih')->default('Original'),
                TextEntry::make('download_url')
                    ->label('🌐 URL Download Publik (Customer HP)')
                    ->state(fn ($record) => url('/d/' . $record->qr_token))
                    ->url(fn ($record) => url('/d/' . $record->qr_token))
                    ->openUrlInNewTab()
                    ->copyable()
                    ->copyMessage('URL Download berhasil disalin!')
                    ->columnSpan(2),
                TextEntry::make('qr_token')->label('QR Token')->copyable(),
                TextEntry::make('expires_at')->label('Masa Aktif Hingga')->dateTime('d M Y H:i:s'),
                TextEntry::make('status_aktif')
                    ->label('Status Kedaluwarsa')
                    ->badge()
                    ->state(fn ($record) => now()->greaterThan($record->expires_at) ? 'Expired (Lewat 7 Hari)' : 'Aktif')
                    ->color(fn ($state) => str_contains($state, 'Aktif') ? 'success' : 'danger'),
            ])->columns(3),

            Section::make('File Hasil Generasi (HD, GIF & Video)')->schema([
                ImageEntry::make('final_url')->label('Photo Strip HD')->disk('public'),
                ImageEntry::make('gif_url')->label('Motion GIF Looping')->disk('public'),
                TextEntry::make('video_url')->label('Live Video URL')->placeholder('Tidak ada video')->url(fn ($state) => $state ? asset('storage/' . $state) : null)->openUrlInNewTab(),
            ])->columns(3),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('session.cafe.name')->label('Cafe')->badge()->color('primary')->searchable()->sortable(),
                ImageColumn::make('final_url')
                    ->label('Preview Foto')
                    ->disk('public')
                    ->square(),
                TextColumn::make('session_id')->label('Sesi')->sortable(),
                TextColumn::make('qr_token')->label('QR Token')->searchable()->copyable(),
                TextColumn::make('expires_at')->label('Expired')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->actions([
                ViewAction::make()->label('Detail'),
                Action::make('open_download')
                    ->label('Download Link')
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->color('success')
                    ->url(fn ($record) => url('/d/' . $record->qr_token))
                    ->openUrlInNewTab(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalResults::route('/'),
            'view'  => Pages\ViewGlobalResult::route('/{record}'),
        ];
    }
}
