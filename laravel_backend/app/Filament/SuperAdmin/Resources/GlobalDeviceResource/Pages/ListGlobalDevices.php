<?php

namespace App\Filament\SuperAdmin\Resources\GlobalDeviceResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalDeviceResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalDevices extends ListRecords
{
    protected static string $resource = GlobalDeviceResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Registrasi Mesin Baru'),
        ];
    }
}
