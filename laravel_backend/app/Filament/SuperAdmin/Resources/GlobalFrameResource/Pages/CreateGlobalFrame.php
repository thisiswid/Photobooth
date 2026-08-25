<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalFrame extends CreateRecord
{
    protected static string $resource = GlobalFrameResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
