<?php

namespace App\Filament\Resources\ResultResource\Pages;

use App\Filament\Resources\ResultResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\ViewRecord;

class ViewResult extends ViewRecord
{
    protected static string $resource = ResultResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make()
                ->label('Hapus Hasil Foto')
                ->modalHeading('Hapus Hasil Foto')
                ->modalDescription('Apakah Anda yakin ingin menghapus hasil foto ini beserta seluruh filenya?')
                ->successNotificationTitle('Hasil foto berhasil dihapus.')
                ->successRedirectUrl(fn () => $this->getResource()::getUrl('index')),
        ];
    }
}
