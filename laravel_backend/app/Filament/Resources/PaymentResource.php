<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentResource\Pages;
use App\Models\Payment;
use Filament\Schemas\Schema;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
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
            Section::make('Detail Transaksi')->schema([
                TextEntry::make('session_id')->label('ID Sesi'),
                TextEntry::make('xendit_payment_id')->label('Xendit ID'),
                TextEntry::make('amount')->label('Jumlah')->money('IDR'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextEntry::make('paid_at')->label('Dibayar')->dateTime('d M Y H:i:s'),
            ])->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->sortable(),
                TextColumn::make('session_id')->label('ID Sesi'),
                TextColumn::make('xendit_payment_id')->label('Xendit ID')->searchable(),
                TextColumn::make('amount')->label('Jumlah')->money('IDR')->sortable(),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'paid'   => 'success',
                        'failed' => 'danger',
                        default  => 'warning',
                    }),
                TextColumn::make('paid_at')->label('Dibayar')->dateTime('d M Y H:i')->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options(['pending' => 'Pending', 'paid' => 'Paid', 'failed' => 'Failed']),
            ])
            ->actions([ViewAction::make()])
            ->poll('15s');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPayments::route('/'),
            'view'  => Pages\ViewPayment::route('/{record}'),
        ];
    }
}
