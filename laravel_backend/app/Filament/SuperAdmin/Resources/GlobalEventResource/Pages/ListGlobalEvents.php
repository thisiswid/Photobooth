<?php

namespace App\Filament\SuperAdmin\Resources\GlobalEventResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalEventResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalEvents extends ListRecords
{
    protected static string $resource = GlobalEventResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Event'),
        ];
    }
}
