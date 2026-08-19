<?php

namespace App\Filament\SuperAdmin\Resources\PlatformUserResource\Pages;

use App\Filament\SuperAdmin\Resources\PlatformUserResource;
use Filament\Resources\Pages\CreateRecord;

class CreatePlatformUser extends CreateRecord
{
    protected static string $resource = PlatformUserResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
