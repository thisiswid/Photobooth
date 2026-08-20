<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SessionResource\Pages;
use App\Models\Session;
use Filament\Schemas\Schema;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class SessionResource extends Resource
{
    protected static ?string $model = Session::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-clock'; }
    public static function getNavigationGroup(): string { return 'Operasional'; }
    public static function getNavigationSort(): int { return 1; }
    public static function getModelLabel(): string { return 'Sesi Foto'; }
    public static function getPluralModelLabel(): string { return 'Sesi Foto'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Sesi')->schema([
                TextEntry::make('id')->label('ID Sesi'),
                TextEntry::make('event.name')->label('Event')->placeholder('-'),
                TextEntry::make('frame.name')->label('Frame Terpilih')->placeholder('-'),
                TextEntry::make('filter.name')->label('Filter Terpilih')->state(fn ($record) => $record->selected_filter ?? 'Original')->placeholder('-'),
                TextEntry::make('status')->label('Status Sesi')->badge()
                    ->color(fn ($state) => match($state) {
                        'finished'     => 'success',
                        'active'       => 'info',
                        'processing'   => 'warning',
                        'result_ready' => 'primary',
                        'timeout'      => 'danger',
                        default        => 'gray',
                    }),
                TextEntry::make('retake_count')->label('Jumlah Retake')->default(0),
            ])->columns(3),

            Section::make('Waktu & Durasi')->schema([
                TextEntry::make('started_at')->label('Waktu Mulai')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('expires_at')->label('Batas Timer (5 Menit)')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('finished_at')->label('Waktu Selesai')->dateTime('d M Y H:i:s')->placeholder('-'),
            ])->columns(3),

            Section::make('Informasi Pembayaran')->schema([
                TextEntry::make('payment.status')->label('Status Pembayaran')->badge()
                    ->state(fn ($record) => $record->payment ? $record->payment->status : ($record->status === 'finished' ? 'paid' : 'unpaid'))
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextEntry::make('payment.amount')->label('Nominal')->state(fn ($record) => $record->payment?->amount)->money('IDR')->placeholder('-'),
                TextEntry::make('payment.paid_at')->label('Waktu Bayar')->state(fn ($record) => $record->payment?->paid_at ?? ($record->status === 'finished' ? $record->started_at : null))->dateTime('d M Y H:i:s')->placeholder('-'),
            ])->columns(3),

            Section::make('Akses Hasil & Download')->schema([
                TextEntry::make('result.qr_token')->label('QR Token')->placeholder('-'),
                TextEntry::make('download_url')
                    ->label('🌐 Link Download Customer')
                    ->state(fn ($record) => $record->result ? url('/d/' . $record->result->qr_token) : null)
                    ->url(fn ($record) => $record->result ? url('/d/' . $record->result->qr_token) : null)
                    ->openUrlInNewTab()
                    ->copyable()
                    ->placeholder('-'),
                TextEntry::make('result.expires_at')->label('Masa Aktif 7 Hari')->dateTime('d M Y H:i:s')->placeholder('-'),
            ])->columns(3),

            Section::make('Preview Hasil Akhir')->schema([
                ImageEntry::make('result.final_url')->label('Photo Strip HD')->disk('public'),
                ImageEntry::make('result.gif_url')->label('Motion GIF Looping')->disk('public'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('event.name')->label('Event')->default('Main Booth')->sortable(),
                TextColumn::make('frame.name')->label('Frame')->default('-'),
                TextColumn::make('selected_filter')->label('Filter')->default('Original'),
                TextColumn::make('status')->label('Status Sesi')->badge()
                    ->color(fn ($state) => match($state) {
                        'finished'     => 'success',
                        'active'       => 'info',
                        'processing'   => 'warning',
                        'result_ready' => 'primary',
                        'timeout'      => 'danger',
                        default        => 'gray',
                    }),
                TextColumn::make('retake_count')->label('Retake'),
                TextColumn::make('started_at')->label('Mulai')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('finished_at')->label('Selesai')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'active'       => 'Active',
                        'processing'   => 'Processing',
                        'result_ready' => 'Result Ready',
                        'finished'     => 'Finished',
                        'timeout'      => 'Timeout'
                    ]),
            ])
            ->actions([
                ViewAction::make()->label('Detail'),
                Action::make('open_download')
                    ->label('Lihat Hasil')
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->color('success')
                    ->visible(fn ($record) => $record->result !== null)
                    ->url(fn ($record) => $record->result ? url('/d/' . $record->result->qr_token) : null)
                    ->openUrlInNewTab(),
                DeleteAction::make(),
            ])
            ->poll('10s');
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where(function ($q) use ($cafeId) {
                $q->where('cafe_id', $cafeId)
                  ->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId));
            });
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSessions::route('/'),
            'view'  => Pages\ViewSession::route('/{record}'),
        ];
    }
}
