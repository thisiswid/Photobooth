<?php

namespace App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalTimerSetting extends CreateRecord
{
    protected static string $resource = GlobalTimerSettingResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
