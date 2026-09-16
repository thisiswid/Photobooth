<?php

namespace App\Filament\Resources;

use App\Filament\Resources\WithdrawalResource\Pages;
use App\Filament\Resources\WithdrawalResource\Widgets\WithdrawalOverviewWidget;
use App\Models\Withdrawal;
use App\Services\WithdrawalPolicyService;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class WithdrawalResource extends Resource
{
    protected static ?string $model = Withdrawal::class;

    public static function getNavigationIcon(): string
    {
        return 'heroicon-o-banknotes';
    }

    public static function getNavigationGroup(): string
    {
        return 'Keuangan';
    }

    public static function getNavigationSort(): int
    {
        return 1;
    }

    public static function getModelLabel(): string
    {
        return 'Penarikan Dana';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Penarikan Dana (Withdrawal)';
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();
        if ($cafeId = auth()->user()?->cafe_id) {
            $query->where('cafe_id', $cafeId);
        }

        return $query->latest();
    }

    public static function form(Schema $schema): Schema
    {
        $cafe = auth()->user()?->cafe;
        $maxBalance = $cafe?->available_balance ?? 0;

        return $schema->components([
            Section::make('Form Pengajuan Penarikan Saldo')
                ->description('Saldo yang dapat ditarik saat ini: Rp '.number_format($maxBalance, 0, ',', '.'))
                ->schema([
                    Select::make('type')
                        ->label('Jenis Penarikan')
                        ->options([
                            WithdrawalPolicyService::TYPE_MANUAL => 'Manual — gratis, khusus Jumat',
                            WithdrawalPolicyService::TYPE_AUTOMATIC => 'Otomatis — berbiaya, Senin–Sabtu',
                        ])
                        ->default(WithdrawalPolicyService::TYPE_MANUAL)
                        ->live()
                        ->required()
                        ->helperText('Transfer otomatis tetap menunggu konfirmasi karena Pakasir belum menyediakan API payout publik.'),

                    TextInput::make('amount')
                        ->label('Saldo yang Dipotong (Rp)')
                        ->numeric()
                        ->prefix('Rp')
                        ->minValue(fn (Get $get) => $get('type') === WithdrawalPolicyService::TYPE_AUTOMATIC ? 15000 : 50000)
                        ->maxValue(fn (Get $get) => $get('type') === WithdrawalPolicyService::TYPE_MANUAL ? min($maxBalance, 500000) : $maxBalance)
                        ->live(onBlur: true)
                        ->required()
                        ->helperText(fn (Get $get) => $get('type') === WithdrawalPolicyService::TYPE_AUTOMATIC
                            ? 'Minimal Rp 15.000. Biaya dipotong dari nominal ini.'
                            : 'Rp 50.000–Rp 500.000, tanpa biaya admin.'),

                    Placeholder::make('withdrawal_summary')
                        ->label('Estimasi Dana Diterima')
                        ->content(function (Get $get): string {
                            $type = $get('type') ?: WithdrawalPolicyService::TYPE_MANUAL;
                            $amount = (int) ($get('amount') ?: 0);
                            $fee = WithdrawalPolicyService::adminFee($type, $amount);
                            $net = WithdrawalPolicyService::netAmount($type, $amount);

                            return 'Biaya Rp '.number_format($fee, 0, ',', '.').' • diterima Rp '.number_format($net, 0, ',', '.');
                        }),

                    TextInput::make('bank_name')
                        ->label('Nama Bank Tujuan')
                        ->placeholder('Contoh: BCA / Mandiri / BRI / BNI / Jago')
                        ->default(fn () => $cafe?->bank_name)
                        ->required(),

                    TextInput::make('bank_account_number')
                        ->label('Nomor Rekening Tujuan')
                        ->placeholder('Contoh: 1234567890')
                        ->default(fn () => $cafe?->bank_account_number)
                        ->required(),

                    TextInput::make('bank_account_holder')
                        ->label('Nama Pemilik Rekening')
                        ->placeholder('Contoh: Budi Santoso')
                        ->default(fn () => $cafe?->bank_account_holder ?? $cafe?->pic_name)
                        ->required(),

                    Textarea::make('notes')
                        ->label('Catatan Pengajuan (Opsional)')
                        ->rows(2)
                        ->columnSpanFull(),
                ])->columns(2),
        ]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Penarikan Dana')->schema([
                TextEntry::make('reference_no')->label('Nomor Referensi')->copyable(),
                TextEntry::make('type')->label('Jenis')->badge()
                    ->formatStateUsing(fn ($state) => $state === WithdrawalPolicyService::TYPE_AUTOMATIC ? 'Otomatis' : 'Manual')
                    ->color(fn ($state) => $state === WithdrawalPolicyService::TYPE_AUTOMATIC ? 'info' : 'success'),
                TextEntry::make('amount')->label('Saldo Dipotong')->money('IDR'),
                TextEntry::make('admin_fee')->label('Biaya Admin')->money('IDR')->color('danger'),
                TextEntry::make('net_amount')->label('Dana Diterima')->money('IDR')->color('success'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match ($state) {
                        'approved' => 'success',
                        'rejected' => 'danger',
                        default => 'warning',
                    }),
                TextEntry::make('created_at')->label('Waktu Pengajuan')->dateTime('d M Y H:i:s'),
                TextEntry::make('bank_name')->label('Bank Tujuan'),
                TextEntry::make('bank_account_number')->label('Nomor Rekening'),
                TextEntry::make('bank_account_holder')->label('Nama Penerima'),
                TextEntry::make('processed_at')->label('Waktu Diproses')->dateTime('d M Y H:i:s')->placeholder('Menunggu verifikasi'),
                TextEntry::make('processor.name')->label('Diproses Oleh')->placeholder('Admin Platform'),
                TextEntry::make('notes')->label('Catatan / Alasan')->columnSpanFull()->placeholder('-'),
            ])->columns(3),

            Section::make('Bukti Transfer Bank')
                ->schema([
                    ImageEntry::make('proof_of_transfer_path')
                        ->label('Foto Bukti Transfer')
                        ->disk('public')
                        ->columnSpanFull(),
                ])
                ->visible(fn ($record) => ! empty($record->proof_of_transfer_path)),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('reference_no')
                    ->label('No. Ref')
                    ->searchable()
                    ->copyable()
                    ->sortable(),
                TextColumn::make('amount')
                    ->label('Saldo Dipotong')
                    ->money('IDR')
                    ->sortable(),
                TextColumn::make('type')->label('Jenis')->badge()
                    ->formatStateUsing(fn ($state) => $state === WithdrawalPolicyService::TYPE_AUTOMATIC ? 'Otomatis' : 'Manual')
                    ->color(fn ($state) => $state === WithdrawalPolicyService::TYPE_AUTOMATIC ? 'info' : 'success'),
                TextColumn::make('admin_fee')->label('Biaya')->money('IDR')->color('danger'),
                TextColumn::make('net_amount')->label('Diterima')->money('IDR')->color('success'),
                TextColumn::make('bank_name')
                    ->label('Bank')
                    ->badge()
                    ->color('info'),
                TextColumn::make('bank_account_number')
                    ->label('No. Rekening')
                    ->description(fn ($record) => $record->bank_account_holder),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'approved' => 'success',
                        'rejected' => 'danger',
                        default => 'warning',
                    }),
                TextColumn::make('created_at')
                    ->label('Waktu Pengajuan')
                    ->dateTime('d M Y H:i')
                    ->sortable(),
                TextColumn::make('processed_at')
                    ->label('Waktu Selesai')
                    ->dateTime('d M Y H:i')
                    ->placeholder('-'),
            ])
            ->actions([
                ViewAction::make(),
            ]);
    }

    public static function getWidgets(): array
    {
        return [
            WithdrawalOverviewWidget::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWithdrawals::route('/'),
            'create' => Pages\CreateWithdrawal::route('/create'),
            'view' => Pages\ViewWithdrawal::route('/{record}'),
        ];
    }
}
