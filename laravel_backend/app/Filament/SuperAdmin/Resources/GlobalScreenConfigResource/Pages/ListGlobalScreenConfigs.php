<?php

namespace App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalScreenConfigs extends ListRecords
{
    protected static string $resource = GlobalScreenConfigResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Screen Config'),
        ];
    }
}
