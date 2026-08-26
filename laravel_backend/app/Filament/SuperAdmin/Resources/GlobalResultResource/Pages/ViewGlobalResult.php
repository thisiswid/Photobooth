<?php

namespace App\Filament\SuperAdmin\Resources\GlobalResultResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalResultResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\ViewRecord;

class ViewGlobalResult extends ViewRecord
{
    protected static string $resource = GlobalResultResource::class;

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
