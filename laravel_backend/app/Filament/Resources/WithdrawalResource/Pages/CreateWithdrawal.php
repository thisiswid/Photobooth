<?php

namespace App\Filament\Resources\WithdrawalResource\Pages;

use App\Filament\Resources\WithdrawalResource;
use App\Models\Cafe;
use App\Models\User;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class CreateWithdrawal extends CreateRecord
{
    protected static string $resource = WithdrawalResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $user = auth()->user();
        $cafe = $user?->cafe;

        if (!$cafe) {
            Notification::make()
                ->title('Gagal Mengajukan Penarikan')
                ->body('Data Cafe tidak ditemukan untuk akun Anda.')
                ->danger()
                ->send();

            $this->halt();
        }

        if ($data['amount'] > $cafe->available_balance) {
            Notification::make()
                ->title('Saldo Tidak Cukup')
                ->body('Nominal penarikan melebihi saldo yang tersedia (Rp ' . number_format($cafe->available_balance, 0, ',', '.') . ').')
                ->danger()
                ->send();

            $this->halt();
        }

        $data['cafe_id'] = $cafe->id;
        $data['user_id'] = $user->id;
        $data['status'] = 'pending';

        // Auto update cafe bank info if updated in form
        $cafe->update([
            'bank_name' => $data['bank_name'],
            'bank_account_number' => $data['bank_account_number'],
            'bank_account_holder' => $data['bank_account_holder'],
        ]);

        return $data;
    }

    protected function handleRecordCreation(array $data): Model
    {
        return DB::transaction(function () use ($data) {
            $cafe = Cafe::query()->lockForUpdate()->findOrFail($data['cafe_id']);

            if ((int) $data['amount'] > $cafe->available_balance) {
                Notification::make()
                    ->title('Saldo Sudah Berubah')
                    ->body('Pengajuan dibatalkan karena saldo tersedia tidak lagi mencukupi.')
                    ->danger()
                    ->send();

                $this->halt();
            }

            return WithdrawalResource::getModel()::create($data);
        });
    }

    protected function afterCreate(): void
    {
        $record = $this->record;

        Notification::make()
            ->title('Pengajuan pencairan baru')
            ->body("{$record->cafe->name} mengajukan {$record->reference_no} sebesar Rp " . number_format($record->amount, 0, ',', '.') . '.')
            ->warning()
            ->sendToDatabase(User::query()->where('role', 'super_admin')->get());

        Notification::make()
            ->title('Pengajuan pencairan diterima')
            ->body("{$record->reference_no} berstatus pending dan sedang menunggu respons Super Admin.")
            ->warning()
            ->sendToDatabase(auth()->user());
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
