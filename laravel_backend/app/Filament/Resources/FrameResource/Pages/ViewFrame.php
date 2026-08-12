<?php

namespace App\Filament\Resources\FrameResource\Pages;

use App\Filament\Resources\FrameResource;
use Filament\Actions\EditAction;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\ViewRecord;

class ViewFrame extends ViewRecord
{
    protected static string $resource = FrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            EditAction::make(),
            DeleteAction::make(),
        ];
    }
}
