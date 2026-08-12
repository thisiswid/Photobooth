<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SessionResource\Pages;
use App\Models\Session;
use Filament\Schemas\Schema;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
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
    public static function getModelLabel(): string { return 'Sesi'; }
    public static function getPluralModelLabel(): string { return 'Sesi'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Informasi Sesi')->schema([
                TextEntry::make('event.name')->label('Event'),
                TextEntry::make('frame.name')->label('Frame'),
                TextEntry::make('filter.name')->label('Filter'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'finished'     => 'success',
                        'active'       => 'info',
                        'processing'   => 'warning',
                        'result_ready' => 'primary',
                        'timeout'      => 'danger',
                        default        => 'gray',
                    }),
                TextEntry::make('retake_count')->label('Retake'),
            ])->columns(3),
            Section::make('Waktu')->schema([
                TextEntry::make('started_at')->label('Mulai')->dateTime('d M Y H:i:s'),
                TextEntry::make('expires_at')->label('Expired')->dateTime('d M Y H:i:s'),
                TextEntry::make('finished_at')->label('Selesai')->dateTime('d M Y H:i:s'),
            ])->columns(3),
            Section::make('Pembayaran')->schema([
                TextEntry::make('payment.status')->label('Status Bayar')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextEntry::make('payment.amount')->label('Jumlah')->money('IDR'),
                TextEntry::make('payment.paid_at')->label('Dibayar')->dateTime('d M Y H:i:s'),
            ])->columns(3),
            Section::make('Hasil')->schema([
                TextEntry::make('result.qr_token')->label('QR Token'),
                TextEntry::make('result.expires_at')->label('Expired')->dateTime('d M Y H:i:s'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('event.name')->label('Event')->sortable(),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'finished'     => 'success',
                        'active'       => 'info',
                        'processing'   => 'warning',
                        'result_ready' => 'primary',
                        'timeout'      => 'danger',
                        default        => 'gray',
                    }),
                TextColumn::make('payment.status')->label('Bayar')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextColumn::make('retake_count')->label('Retake'),
                TextColumn::make('started_at')->label('Mulai')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('finished_at')->label('Selesai')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options(['pending'=>'Pending','active'=>'Active','processing'=>'Processing','result_ready'=>'Result Ready','finished'=>'Finished','timeout'=>'Timeout']),
            ])
            ->actions([ViewAction::make(), DeleteAction::make()])
            ->poll('10s');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSessions::route('/'),
            'view'  => Pages\ViewSession::route('/{record}'),
        ];
    }
}
