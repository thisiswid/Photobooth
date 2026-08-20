<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFilterResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFilterResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalFilter extends CreateRecord
{
    protected static string $resource = GlobalFilterResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
