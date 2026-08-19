<?php

namespace App\Filament\SuperAdmin\Resources\GlobalDeviceResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalDeviceResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalDevice extends CreateRecord
{
    protected static string $resource = GlobalDeviceResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
