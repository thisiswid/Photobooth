<?php

namespace App\Filament\SuperAdmin\Resources\CafeResource\Pages;

use App\Filament\SuperAdmin\Resources\CafeResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListCafes extends ListRecords
{
    protected static string $resource = CafeResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Cafe / Tenant'),
        ];
    }
}
