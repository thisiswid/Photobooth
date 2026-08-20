<?php

namespace App\Filament\Resources\TimerSettingResource\Pages;

use App\Filament\Resources\TimerSettingResource;
use Filament\Resources\Pages\CreateRecord;

class CreateTimerSetting extends CreateRecord
{
    protected static string $resource = TimerSettingResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        if (empty($data['cafe_id']) && ($cafeId = auth()->user()?->cafe_id)) {
            $data['cafe_id'] = $cafeId;
        }
        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
