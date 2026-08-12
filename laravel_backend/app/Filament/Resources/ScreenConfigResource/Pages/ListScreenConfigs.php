<?php

namespace App\Filament\Resources\ScreenConfigResource\Pages;

use App\Filament\Resources\ScreenConfigResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListScreenConfigs extends ListRecords
{
    protected static string $resource = ScreenConfigResource::class;

    protected function getHeaderActions(): array
    {
        return [CreateAction::make()];
    }
}
