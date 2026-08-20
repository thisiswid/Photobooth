<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFilterResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFilterResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalFilters extends ListRecords
{
    protected static string $resource = GlobalFilterResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Filter Foto'),
        ];
    }
}
