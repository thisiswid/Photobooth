<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\GlobalWithdrawalResource\Pages;
use App\Models\Withdrawal;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Textarea;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class GlobalWithdrawalResource extends Resource
{
    protected static ?string $model = Withdrawal::class;

    public static function getNavigationIcon(): string { return 'heroicon-o-banknotes'; }
    public static function getNavigationGroup(): string { return 'Finance & Analytics'; }
    public static function getNavigationSort(): int { return 4; }
    public static function getModelLabel(): string { return 'Penarikan Dana Mitra'; }
    public static function getPluralModelLabel(): string { return 'Pencairan Dana (Withdrawals)'; }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Rincian Penarikan Dana Mitra')->schema([
                TextEntry::make('reference_no')->label('Nomor Referensi')->copyable(),
                TextEntry::make('cafe.name')->label('Tenant / Cafe')->badge()->color('primary'),
                TextEntry::make('user.name')->label('Diajukan Oleh'),
                TextEntry::make('amount')->label('Nominal Pencairan')->money('IDR', locale: 'id'),
                TextEntry::make('status')->label('Status')->badge()
                    ->color(fn ($state) => match($state) {
                        'approved' => 'success',
                        'rejected' => 'danger',
                        default    => 'warning',
                    }),
                TextEntry::make('created_at')->label('Waktu Pengajuan')->dateTime('d M Y H:i:s'),
                TextEntry::make('bank_name')->label('Bank Tujuan'),
                TextEntry::make('bank_account_number')->label('Nomor Rekening')->copyable(),
                TextEntry::make('bank_account_holder')->label('Nama Pemilik Rekening'),
                TextEntry::make('processed_at')->label('Waktu Diproses')->dateTime('d M Y H:i:s')->placeholder('-'),
                TextEntry::make('processor.name')->label('Diproses Oleh')->placeholder('-'),
                TextEntry::make('notes')->label('Catatan / Alasan Penolakan')->columnSpanFull()->placeholder('-'),
            ])->columns(3),

            Section::make('Bukti Transfer Bank')
                ->schema([
                    ImageEntry::make('proof_of_transfer_path')
                        ->label('Foto Bukti Transfer')
                        ->disk('public')
                        ->columnSpanFull(),
                ])
                ->visible(fn ($record) => !empty($record->proof_of_transfer_path)),
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
                TextColumn::make('cafe.name')
                    ->label('Mitra / Cafe')
                    ->badge()
                    ->color('primary')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('amount')
                    ->label('Nominal')
                    ->money('IDR', locale: 'id')
                    ->sortable(),
                TextColumn::make('cafe.total_revenue')
                    ->label('Omzet Cafe')
                    ->state(fn (Withdrawal $record) => $record->cafe?->total_revenue ?? 0)
                    ->money('IDR')
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('cafe.available_balance')
                    ->label('Sisa Saldo')
                    ->state(fn (Withdrawal $record) => $record->cafe?->available_balance ?? 0)
                    ->money('IDR'),
                TextColumn::make('bank_name')
                    ->label('Bank')
                    ->badge()
                    ->color('info'),
                TextColumn::make('bank_account_number')
                    ->label('Rekening')
                    ->description(fn ($record) => $record->bank_account_holder)
                    ->copyable(),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(fn ($state) => match($state) {
                        'approved' => 'success',
                        'rejected' => 'danger',
                        default    => 'warning',
                    }),
                TextColumn::make('created_at')
                    ->label('Waktu Diajukan')
                    ->dateTime('d M Y H:i')
                    ->sortable(),
                TextColumn::make('processor.name')
                    ->label('Diproses')
                    ->placeholder('-'),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'pending'  => 'Pending (Menunggu)',
                        'approved' => 'Approved (Ditransfer)',
                        'rejected' => 'Rejected (Ditolak)',
                    ]),
            ])
            ->actions([
                ViewAction::make(),
                Action::make('approve')
                    ->label('Setujui & Transfer')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->visible(fn (Withdrawal $record) => $record->status === 'pending')
                    ->form([
                        FileUpload::make('proof_of_transfer_path')
                            ->label('Upload Bukti Transfer')
                            ->directory('withdrawals/proofs')
                            ->disk('public')
                            ->image()
                            ->required(),
                        Textarea::make('notes')
                            ->label('Catatan Transfer (Opsional)')
                            ->placeholder('Nomor referensi mutasi bank atau info tambahan'),
                    ])
                    ->requiresConfirmation()
                    ->action(function (Withdrawal $record, array $data): void {
                        \Illuminate\Support\Facades\DB::transaction(function () use ($record, $data): void {
                            $locked = Withdrawal::query()->lockForUpdate()->findOrFail($record->id);
                            if (!$locked->isPending()) {
                                return;
                            }
                            $locked->update([
                                'status' => 'approved',
                                'proof_of_transfer_path' => $data['proof_of_transfer_path'],
                                'notes' => $data['notes'] ?? $locked->notes,
                                'processed_by' => auth()->id(),
                                'processed_at' => now(),
                            ]);
                        });

                        Notification::make()
                            ->title('Pencairan Dana Berhasil Disetujui')
                            ->success()
                            ->send();
                    }),

                Action::make('reject')
                    ->label('Tolak')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (Withdrawal $record) => $record->status === 'pending')
                    ->form([
                        Textarea::make('notes')
                            ->label('Alasan Penolakan')
                            ->required()
                            ->placeholder('Contoh: Nomor rekening tidak cocok dengan nama pemilik atau data tidak valid.'),
                    ])
                    ->requiresConfirmation()
                    ->action(function (Withdrawal $record, array $data): void {
                        \Illuminate\Support\Facades\DB::transaction(function () use ($record, $data): void {
                            $locked = Withdrawal::query()->lockForUpdate()->findOrFail($record->id);
                            if (!$locked->isPending()) {
                                return;
                            }
                            $locked->update([
                                'status' => 'rejected',
                                'notes' => $data['notes'],
                                'processed_by' => auth()->id(),
                                'processed_at' => now(),
                            ]);
                        });

                        Notification::make()
                            ->title('Pengajuan Penarikan Ditolak')
                            ->danger()
                            ->send();
                    }),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGlobalWithdrawals::route('/'),
        ];
    }
}
