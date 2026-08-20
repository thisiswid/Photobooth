<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalFrames extends ListRecords
{
    protected static string $resource = GlobalFrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Frame Cafe'),
        ];
    }
}
