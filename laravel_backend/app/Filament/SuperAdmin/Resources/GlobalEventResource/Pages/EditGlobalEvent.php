<?php

namespace App\Filament\SuperAdmin\Resources\GlobalEventResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalEventResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalEvent extends EditRecord
{
    protected static string $resource = GlobalEventResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
