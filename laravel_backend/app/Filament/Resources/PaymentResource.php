<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentResource\Pages;
use App\Models\Payment;
use Filament\Schemas\Schema;
use Filament\Schemas\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class PaymentResource extends Resource
{
    protected static ?string $model = Payment::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-banknotes'; }
    public static function getNavigationGroup(): string { return 'Operasional'; }
    public static function getNavigationSort(): int { return 2; }
    public static function getModelLabel(): string { return 'Transaksi'; }
    public static function getPluralModelLabel(): string { return 'Transaksi'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Transaksi Pembayaran')->schema([
                TextEntry::make('id')->label('ID Transaksi'),
                TextEntry::make('session.id')->label('ID Sesi Foto'),
                TextEntry::make('session.event.name')->label('Event')->default('Fakultas Kopi Main Booth'),
                TextEntry::make('amount')->label('Nominal Pembayaran')->money('IDR'),
                TextEntry::make('payment_method')->label('Metode Bayar')->default('QRIS Instant'),
                TextEntry::make('status')->label('Status Pembayaran')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextEntry::make('xendit_payment_id')->label('ID Referensi Gateway')->default('-')->copyable(),
                TextEntry::make('paid_at')->label('Waktu Pembayaran Sukses')->dateTime('d M Y H:i:s'),
                TextEntry::make('created_at')->label('Waktu Dibuat')->dateTime('d M Y H:i:s'),
            ])->columns(3),

            Section::make('Relasi Sesi Foto Terkait')->schema([
                TextEntry::make('session.frame.name')->label('Frame Dipilih')->default('-'),
                TextEntry::make('session.filter.name')->label('Filter Dipilih')->default('Original'),
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
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('session.id')->label('ID Sesi')->sortable(),
                TextColumn::make('session.event.name')->label('Event')->default('Main Booth'),
                TextColumn::make('amount')->label('Nominal')->money('IDR')->sortable(),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextColumn::make('paid_at')->label('Waktu Bayar')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options(['pending' => 'Pending', 'paid' => 'Paid', 'failed' => 'Failed']),
            ])
            ->actions([
                ViewAction::make()->label('Detail'),
                Action::make('simulate_paid')
                    ->label('⚡ Bayar Lunas')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('Konfirmasi Pembayaran Lunas')
                    ->modalDescription('Apakah Anda ingin menandai pembayaran ini sebagai SUKSES / LUNAS? Sesi foto akan otomatis aktif.')
                    ->visible(fn ($record) => $record->status === 'pending')
                    ->action(function ($record) {
                        \App\Services\XenditService::simulatePaid($record);
                        \Filament\Notifications\Notification::make()
                            ->title('Pembayaran berhasil diverifikasi & sesi foto diaktifkan!')
                            ->success()
                            ->send();
                    }),
                Action::make('view_session')
                    ->label('Lihat Sesi')
                    ->icon('heroicon-o-clock')
                    ->url(fn ($record) => $record->session_id ? url('/admin/sessions/' . $record->session_id) : null),
            ])
            ->poll('15s');
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->whereHas('session', fn ($sq) => 
                $sq->where('cafe_id', $cafeId)
                   ->orWhereHas('event', fn ($eq) => $eq->where('cafe_id', $cafeId))
            );
        }
        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPayments::route('/'),
            'view'  => Pages\ViewPayment::route('/{record}'),
        ];
    }
}
