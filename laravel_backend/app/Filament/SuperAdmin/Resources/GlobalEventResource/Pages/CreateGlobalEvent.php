<?php

namespace App\Filament\SuperAdmin\Resources\GlobalEventResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalEventResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalEvent extends CreateRecord
{
    protected static string $resource = GlobalEventResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
