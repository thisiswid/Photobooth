<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentReconciliationResource\Pages;
use App\Models\PaymentReconciliation;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class PaymentReconciliationResource extends Resource
{
    protected static ?string $model = PaymentReconciliation::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-arrows-right-left';
    }

    public static function getNavigationGroup(): string
    {
        return 'Operasional';
    }

    public static function getNavigationSort(): int
    {
        return 3;
    }

    public static function getModelLabel(): string
    {
        return 'Riwayat Rekonsiliasi';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Rekonsiliasi Pakasir';
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('checked_at')->label('Diperiksa')->dateTime('d M Y H:i:s')->sortable(),
            TextColumn::make('payment.xendit_payment_id')->label('Order ID')->searchable()->copyable(),
            TextColumn::make('result')->label('Hasil')->badge()->color(fn ($state) => match ($state) {
                'matched' => 'success', 'updated' => 'info', 'pending' => 'warning', default => 'danger',
            }),
            TextColumn::make('local_status_before')->label('Status Lokal')->badge(),
            TextColumn::make('gateway_status')->label('Status Pakasir')->badge()->placeholder('-'),
            TextColumn::make('expected_amount')->label('Tagihan')->money('IDR'),
            TextColumn::make('gateway_amount')->label('Nominal Gateway')->money('IDR')->placeholder('-'),
            TextColumn::make('source')->label('Sumber')->badge(),
            TextColumn::make('checker.name')->label('Pemeriksa')->placeholder('Sistem'),
            TextColumn::make('message')->label('Keterangan')->wrap()->limit(80),
        ])->defaultSort('checked_at', 'desc')->filters([
            SelectFilter::make('result')->options([
                'matched' => 'Sesuai', 'updated' => 'Diperbarui', 'pending' => 'Pending',
                'mismatch' => 'Tidak Cocok', 'error' => 'Error',
            ]),
        ]);
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }

        return $query;
    }

    public static function getPages(): array
    {
        return ['index' => Pages\ListPaymentReconciliations::route('/')];
    }
}
