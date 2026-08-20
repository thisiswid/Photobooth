<?php

namespace App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalTimerSetting extends EditRecord
{
    protected static string $resource = GlobalTimerSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
