<?php

namespace App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalScreenConfig extends CreateRecord
{
    protected static string $resource = GlobalScreenConfigResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
