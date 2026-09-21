<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalPaymentResource\Pages;
use App\Models\Payment;
use App\Services\PakasirReconciliationService;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\TextEntry;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalPaymentResource extends Resource
{
    protected static ?string $model = Payment::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-banknotes';
    }

    public static function getNavigationGroup(): string
    {
        return 'Finance & Analytics';
    }

    public static function getNavigationSort(): int
    {
        return 3;
    }

    public static function getModelLabel(): string
    {
        return 'Transaksi Global';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Semua Transaksi & Omset';
    }

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
                TextEntry::make('amount')->label('Pembayaran Bruto')->money('IDR', locale: 'id'),
                TextEntry::make('provider_fee')->label('Biaya Pakasir')
                    ->formatStateUsing(fn ($state) => (int) $state > 0 ? '- Rp '.number_format((float) $state, 0, ',', '.') : 'Rp 0')
                    ->color('danger'),
                TextEntry::make('net_amount')->label('Neto Milik Cafe')->money('IDR', locale: 'id')->color('success'),
                TextEntry::make('settlement_status')->label('Settlement')->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'settled' => 'Saldo Tersedia',
                        'pending' => 'Saldo Tertunda',
                        default => 'Tidak Berlaku',
                    })
                    ->color(fn ($state) => match ($state) {
                        'settled' => 'success',
                        'pending' => 'warning',
                        default => 'gray',
                    }),
                TextEntry::make('settlement_due_at')->label('Jadwal Settlement')
                    ->formatStateUsing(fn ($state) => $state?->timezone('Asia/Jakarta')->format('d M Y H:i').' WIB')
                    ->placeholder('-'),
                TextEntry::make('original_amount')->label('Harga Awal')->money('IDR', locale: 'id'),
                TextEntry::make('discount_amount')->label('Diskon Voucher')->money('IDR', locale: 'id'),
                TextEntry::make('voucher.code')->label('Kode Voucher')->badge()->placeholder('-'),
                TextEntry::make('is_simulated')->label('Jenis Dana')->badge()
                    ->formatStateUsing(fn ($state) => $state ? 'Dana Simulasi' : 'Dana Asli')
                    ->color(fn ($state) => $state ? 'warning' : 'success'),
                TextEntry::make('platform_share')
                    ->label('Potongan Platform')
                    ->state('Rp 0 (dinonaktifkan)')
                    ->badge()
                    ->color('success'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match ($state) {
                        'paid' => 'success',
                        'pending' => 'warning',
                        'failed' => 'danger',
                        default => 'gray',
                    }),
                TextEntry::make('payment_method')->label('Metode Pembayaran')->default('QRIS Instant'),
                TextEntry::make('xendit_payment_id')->label('ID Referensi Gateway / QRIS')->copyable()->placeholder('-'),
                TextEntry::make('gateway_status')->label('Status Pakasir')->badge()->placeholder('Belum diperiksa'),
                TextEntry::make('reconciliation_status')->label('Hasil Rekonsiliasi')->badge()
                    ->color(fn ($state) => match ($state) {
                        'matched' => 'success', 'updated' => 'info', 'pending' => 'warning', default => 'danger',
                    })->placeholder('Belum diperiksa'),
                TextEntry::make('last_gateway_check_at')->label('Terakhir Diperiksa')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('reconciliation_message')->label('Catatan Rekonsiliasi')->placeholder('-')->columnSpanFull(),
                TextEntry::make('paid_at')->label('Waktu Pembayaran Sukses')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('created_at')->label('Waktu Dibuat')->dateTime('d M Y H:i:s'),
            ])->columns(3),

            Section::make('Informasi Sesi Foto Terkait')->schema([
                TextEntry::make('session.id')->label('ID Sesi Foto'),
                TextEntry::make('session.event.name')->label('Event')->placeholder('Main Booth'),
                TextEntry::make('session.frame.name')->label('Frame Terpilih')->placeholder('-'),
                TextEntry::make('session.filter.name')->label('Filter Terpilih')->placeholder('Original'),
                TextEntry::make('session.status')->label('Status Sesi')->badge()
                    ->color(fn ($state) => match ($state) {
                        'finished' => 'success',
                        'active' => 'info',
                        default => 'gray',
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
                    ->label('Bruto')
                    ->money('IDR', locale: 'id')
                    ->sortable(),
                TextColumn::make('provider_fee')
                    ->label('Biaya Pakasir')
                    ->formatStateUsing(fn ($state) => (int) $state > 0 ? '- Rp '.number_format((float) $state, 0, ',', '.') : 'Rp 0')
                    ->color('danger')
                    ->sortable(),
                TextColumn::make('net_amount')
                    ->label('Neto Cafe')
                    ->money('IDR', locale: 'id')
                    ->color('success')
                    ->sortable(),
                TextColumn::make('settlement_status')->label('Settlement')->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'settled' => 'Tersedia',
                        'pending' => 'Tertunda',
                        default => '-',
                    })
                    ->color(fn ($state) => match ($state) {
                        'settled' => 'success',
                        'pending' => 'warning',
                        default => 'gray',
                    }),
                TextColumn::make('settlement_due_at')->label('Tersedia Pada')
                    ->formatStateUsing(fn ($state) => $state?->timezone('Asia/Jakarta')->format('d M Y H:i').' WIB')
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('discount_amount')->label('Diskon')->money('IDR', locale: 'id')->toggleable(),
                TextColumn::make('voucher.code')->label('Voucher')->badge()->placeholder('-')->searchable(),
                TextColumn::make('is_simulated')->label('Jenis Dana')->badge()
                    ->formatStateUsing(fn ($state) => $state ? 'Simulasi' : 'Asli')
                    ->color(fn ($state) => $state ? 'warning' : 'success'),
                TextColumn::make('platform_share')
                    ->label('Potongan Platform')
                    ->state('Rp 0')
                    ->badge()
                    ->color('success'),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'paid' => 'success',
                        'pending' => 'warning',
                        'failed' => 'danger',
                        default => 'gray',
                    }),
                TextColumn::make('reconciliation_status')->label('Rekonsiliasi')->badge()
                    ->color(fn ($state) => match ($state) {
                        'matched' => 'success', 'updated' => 'info', 'pending' => 'warning', default => 'danger',
                    })->placeholder('Belum dicek'),
                TextColumn::make('paid_at')
                    ->label('Waktu Bayar')
                    ->dateTime('d M Y, H:i')
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'paid' => 'Paid (Sukses)',
                        'pending' => 'Pending',
                        'failed' => 'Failed',
                    ]),
                SelectFilter::make('is_simulated')->label('Jenis Dana')
                    ->options(['0' => 'Dana Asli', '1' => 'Dana Simulasi']),
                SelectFilter::make('reconciliation_status')->label('Rekonsiliasi')->options([
                    'matched' => 'Sesuai', 'updated' => 'Diperbarui', 'pending' => 'Pending',
                    'mismatch' => 'Tidak Cocok', 'error' => 'Error',
                ]),
            ])
            ->actions([
                ViewAction::make(),
                Action::make('reconcile')
                    ->label('Cek Pakasir')
                    ->icon('heroicon-o-arrows-right-left')
                    ->visible(fn ($record) => ! $record->is_simulated && filled($record->xendit_payment_id))
                    ->action(function ($record, PakasirReconciliationService $service): void {
                        $result = $service->reconcile($record, 'manual', auth()->id());
                        Notification::make()
                            ->title($result?->result === 'error' ? 'Rekonsiliasi gagal' : 'Rekonsiliasi selesai')
                            ->body($result?->message)
                            ->color(in_array($result?->result, ['mismatch', 'error'], true) ? 'danger' : 'success')
                            ->send();
                    }),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalPayments::route('/'),
        ];
    }
}
