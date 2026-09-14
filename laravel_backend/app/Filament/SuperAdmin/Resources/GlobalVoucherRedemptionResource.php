<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalVoucherRedemptionResource\Pages;
use App\Models\VoucherRedemption;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalVoucherRedemptionResource extends Resource
{
    protected static ?string $model = VoucherRedemption::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-clipboard-document-check';
    }

    public static function getNavigationGroup(): string
    {
        return 'Finance & Analytics';
    }

    public static function getNavigationSort(): int
    {
        return 4;
    }

    public static function getModelLabel(): string
    {
        return 'Pemakaian Voucher';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Riwayat Voucher Global';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('cafe.name')->label('Cafe')->badge()->searchable()->sortable(),
            TextColumn::make('voucher.code')->label('Voucher')->badge()->searchable(),
            TextColumn::make('voucher.name')->label('Promo'),
            TextColumn::make('discount_amount')->label('Potongan')->money('IDR')->sortable(),
            TextColumn::make('device.name')->label('Perangkat')->placeholder('-'),
            TextColumn::make('payment_id')->label('Pembayaran')->sortable(),
            TextColumn::make('status')->label('Status')->badge()->color(fn ($state) => match ($state) {
                'used' => 'success', 'released' => 'gray', default => 'warning',
            }),
            TextColumn::make('used_at')->label('Dipakai')->dateTime('d M Y H:i')->placeholder('-')->sortable(),
        ])->filters([
            SelectFilter::make('cafe_id')->label('Cafe')->relationship('cafe', 'name'),
            SelectFilter::make('status')->options(['reserved' => 'Direservasi', 'used' => 'Terpakai', 'released' => 'Dilepas']),
        ])->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return ['index' => Pages\ListGlobalVoucherRedemptions::route('/')];
    }
}
