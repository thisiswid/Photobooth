<?php

namespace App\Filament\SuperAdmin\Resources\CafeResource\Pages;

use App\Filament\SuperAdmin\Resources\CafeResource;
use Filament\Resources\Pages\CreateRecord;

class CreateCafe extends CreateRecord
{
    protected static string $resource = CafeResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
