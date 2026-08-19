<?php

namespace App\Filament\SuperAdmin\Resources\GlobalDeviceResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalDeviceResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalDevice extends EditRecord
{
    protected static string $resource = GlobalDeviceResource::class;

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
