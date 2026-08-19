<?php

namespace App\Filament\SuperAdmin\Resources\MasterFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\MasterFrameResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListMasterFrames extends ListRecords
{
    protected static string $resource = MasterFrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Upload Master Template Baru'),
        ];
    }
}
