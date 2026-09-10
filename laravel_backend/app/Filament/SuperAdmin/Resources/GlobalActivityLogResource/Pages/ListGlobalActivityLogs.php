<?php

namespace App\Filament\SuperAdmin\Resources\GlobalActivityLogResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalActivityLogResource;
use Filament\Resources\Pages\ListRecords;

class ListGlobalActivityLogs extends ListRecords
{
    protected static string $resource = GlobalActivityLogResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
