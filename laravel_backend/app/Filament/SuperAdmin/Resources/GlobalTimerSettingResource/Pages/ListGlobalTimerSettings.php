<?php

namespace App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalTimerSettingResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalTimerSettings extends ListRecords
{
    protected static string $resource = GlobalTimerSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Profil Timer'),
        ];
    }
}
