<?php

namespace App\Filament\Resources\CafeResource\Pages;

use App\Filament\Resources\CafeResource;
use Filament\Resources\Pages\ListRecords;

class ListCafes extends ListRecords
{
    protected static string $resource = CafeResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
