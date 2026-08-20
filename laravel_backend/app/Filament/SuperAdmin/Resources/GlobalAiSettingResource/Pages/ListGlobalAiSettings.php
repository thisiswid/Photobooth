<?php

namespace App\Filament\SuperAdmin\Resources\GlobalAiSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalAiSettingResource;
use Filament\Resources\Pages\ListRecords;

class ListGlobalAiSettings extends ListRecords
{
    protected static string $resource = GlobalAiSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
