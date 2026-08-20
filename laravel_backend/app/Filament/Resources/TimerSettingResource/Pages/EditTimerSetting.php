<?php

namespace App\Filament\Resources\TimerSettingResource\Pages;

use App\Filament\Resources\TimerSettingResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditTimerSetting extends EditRecord
{
    protected static string $resource = TimerSettingResource::class;

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
