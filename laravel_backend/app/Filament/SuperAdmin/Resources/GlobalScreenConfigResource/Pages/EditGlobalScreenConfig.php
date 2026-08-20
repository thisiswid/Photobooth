<?php

namespace App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalScreenConfigResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalScreenConfig extends EditRecord
{
    protected static string $resource = GlobalScreenConfigResource::class;

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
