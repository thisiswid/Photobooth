<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalPaymentResource\Pages;
use App\Models\Payment;
use Filament\Actions\ViewAction;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalPaymentResource extends Resource
{
    protected static ?string $model = Payment::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-banknotes'; }
    public static function getNavigationGroup(): string { return 'Finance & Analytics'; }
    public static function getNavigationSort(): int { return 3; }
    public static function getModelLabel(): string { return 'Transaksi Global'; }
    public static function getPluralModelLabel(): string { return 'Semua Transaksi & Omset'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Transaksi Pembayaran')->schema([
                TextEntry::make('id')->label('ID Transaksi'),
                TextEntry::make('session.cafe.name')->label('Tenant / Cafe')->badge()->color('primary')->placeholder('Tanpa Cafe'),
                TextEntry::make('session.device.name')->label('Mesin Booth')->placeholder('-'),
                TextEntry::make('amount')->label('Nominal Transaksi')->money('IDR', locale: 'id'),
                TextEntry::make('platform_share')
                    ->label('Estimasi Fee Platform')
                    ->state(function (Payment $record): string {
                        $percentage = $record->session?->cafe?->revenue_share_percentage ?? 10;
                        $share = ($record->amount * $percentage) / 100;
                        return 'Rp ' . number_format($share, 0, ',', '.') . " ({$percentage}%)";
                    })
                    ->badge()
                    ->color('success'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'    => 'success',
                        'pending' => 'warning',
                        'failed'  => 'danger',
                        default   => 'gray',
                    }),
                TextEntry::make('payment_method')->label('Metode Pembayaran')->default('QRIS Instant'),
                TextEntry::make('xendit_payment_id')->label('ID Referensi Gateway / QRIS')->copyable()->placeholder('-'),
                TextEntry::make('paid_at')->label('Waktu Pembayaran Sukses')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('created_at')->label('Waktu Dibuat')->dateTime('d M Y H:i:s'),
            ])->columns(3),

            Section::make('Informasi Sesi Foto Terkait')->schema([
                TextEntry::make('session.id')->label('ID Sesi Foto'),
                TextEntry::make('session.event.name')->label('Event')->placeholder('Main Booth'),
                TextEntry::make('session.frame.name')->label('Frame Terpilih')->placeholder('-'),
                TextEntry::make('session.filter.name')->label('Filter Terpilih')->placeholder('Original'),
                TextEntry::make('session.status')->label('Status Sesi')->badge()
                    ->color(fn ($state) => match($state) {
                        'finished' => 'success',
                        'active'   => 'info',
                        default    => 'gray',
                    }),
            ])->columns(3),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),
                TextColumn::make('session.cafe.name')
                    ->label('Cafe / Tenant')
                    ->badge()
                    ->color('primary')
                    ->searchable()
                    ->sortable()
                    ->placeholder('Tanpa Cafe'),
                TextColumn::make('session.device.name')
                    ->label('Mesin Booth')
                    ->placeholder('-'),
                TextColumn::make('xendit_payment_id')
                    ->label('Payment Ref / QRIS')
                    ->searchable()
                    ->copyable()
                    ->placeholder('-'),
                TextColumn::make('amount')
                    ->label('Nominal Transaksi')
                    ->money('IDR', locale: 'id')
                    ->sortable(),
                TextColumn::make('platform_share')
                    ->label('Estimasi Fee Platform')
                    ->state(function (Payment $record): string {
                        $percentage = $record->session?->cafe?->revenue_share_percentage ?? 10;
                        $share = ($record->amount * $percentage) / 100;
                        return 'Rp ' . number_format($share, 0, ',', '.') . " ({$percentage}%)";
                    })
                    ->badge()
                    ->color('success'),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'    => 'success',
                        'pending' => 'warning',
                        'failed'  => 'danger',
                        default   => 'gray',
                    }),
                TextColumn::make('paid_at')
                    ->label('Waktu Bayar')
                    ->dateTime('d M Y, H:i')
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'paid'    => 'Paid (Sukses)',
                        'pending' => 'Pending',
                        'failed'  => 'Failed',
                    ]),
            ])
            ->actions([
                ViewAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalPayments::route('/'),
        ];
    }
}
