<?php

namespace App\Filament\SuperAdmin\Resources\PlatformUserResource\Pages;

use App\Filament\SuperAdmin\Resources\PlatformUserResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListPlatformUsers extends ListRecords
{
    protected static string $resource = PlatformUserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Buat Pengguna Baru'),
        ];
    }
}
