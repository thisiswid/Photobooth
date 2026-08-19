<?php

namespace App\Filament\Resources\ErrorLogResource\Pages;

use App\Filament\Resources\ErrorLogResource;
use App\Models\ErrorLog;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;

class ListErrorLogs extends ListRecords
{
    protected static string $resource = ErrorLogResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('clear_all')
                ->label('Bersihkan Semua Log')
                ->icon('heroicon-o-trash')
                ->color('danger')
                ->requiresConfirmation()
                ->modalHeading('Hapus Semua Riwayat Log Error?')
                ->modalDescription('Tindakan ini akan menghapus seluruh data log diagnostik error dari sistem.')
                ->modalSubmitActionLabel('Ya, Hapus Semua')
                ->action(function () {
                    ErrorLog::truncate();
                    Notification::make()
                        ->title('Semua log error berhasil dibersihkan')
                        ->success()
                        ->send();
                }),
        ];
    }
}
