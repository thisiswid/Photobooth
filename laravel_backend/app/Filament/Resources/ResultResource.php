<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ResultResource\Pages;
use App\Models\Result;
use Filament\Schemas\Schema;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ResultResource extends Resource
{
    protected static ?string $model = Result::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-qr-code'; }
    public static function getNavigationGroup(): string { return 'Operasional'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Hasil Foto'; }
    public static function getPluralModelLabel(): string { return 'Hasil Foto'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Hasil & Akses Download')->schema([
                TextEntry::make('session.id')->label('ID Sesi'),
                TextEntry::make('session.event.name')->label('Event'),
                TextEntry::make('session.frame.name')->label('Frame Terpilih'),
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

            Section::make('File Hasil Generasi (HD, Original & Video)')->schema([
                ImageEntry::make('final_url')
                    ->label('📸 Photo Strip Filter (HD)')
                    ->disk('public'),
                ImageEntry::make('raw_final_url')
                    ->label('🖼️ Photo Strip Asli (Tanpa Filter)')
                    ->disk('public'),
                ImageEntry::make('gif_url')
                    ->label('🎬 Looping Motion GIF')
                    ->disk('public'),
                TextEntry::make('video_url')
                    ->label('🎥 File Video MP4 (Klik untuk Unduh/Putar)')
                    ->state(fn ($record) => $record->video_url ? url('storage/' . $record->video_url) : '-')
                    ->url(fn ($record) => $record->video_url ? url('storage/' . $record->video_url) : null)
                    ->openUrlInNewTab(),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                ImageColumn::make('final_url')->label('Strip Filter')->disk('public')->height(60),
                ImageColumn::make('raw_final_url')->label('Strip Asli')->disk('public')->height(60),
                ImageColumn::make('gif_url')->label('Motion GIF')->disk('public')->height(60),
                TextColumn::make('video_url')
                    ->label('Video MP4')
                    ->state(fn ($record) => $record->video_url ? '▶️ Video MP4' : '-')
                    ->url(fn ($record) => $record->video_url ? url('storage/' . $record->video_url) : null)
                    ->openUrlInNewTab()
                    ->color('warning'),
                TextColumn::make('session.id')->label('ID Sesi')->sortable(),
                TextColumn::make('session.event.name')->label('Event'),
                TextColumn::make('qr_token')->label('QR Token')->searchable()->copyable()->limit(12),
                TextColumn::make('download_link')
                    ->label('Akses Link')
                    ->state(fn ($record) => url('/d/' . $record->qr_token))
                    ->url(fn ($record) => url('/d/' . $record->qr_token))
                    ->openUrlInNewTab()
                    ->color('primary')
                    ->limit(28),
                TextColumn::make('expires_at')
                    ->label('Status 7 Hari')
                    ->badge()
                    ->state(function ($record) {
                        if (now()->greaterThan($record->expires_at)) {
                            return 'Expired';
                        }
                        $days = max(0, (int) now()->diffInDays($record->expires_at, false));
                        return "Aktif ({$days} hari lagi)";
                    })
                    ->color(fn ($state) => str_contains($state, 'Aktif') ? 'success' : 'danger')
                    ->sortable(),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->actions([
                ViewAction::make()->label('Detail'),
                Action::make('open_download')
                    ->label('Buka Download')
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->color('success')
                    ->url(fn ($record) => url('/d/' . $record->qr_token))
                    ->openUrlInNewTab(),
            ]);
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where(function ($q) use ($cafeId) {
                $q->whereHas('session', fn ($sq) => 
                    $sq->where('cafe_id', $cafeId)
                       ->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId))
                       ->orWhereNull('cafe_id')
                )->orDoesntHave('session');
            });
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListResults::route('/'),
            'view'  => Pages\ViewResult::route('/{record}'),
        ];
    }
}
