<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalFrame extends EditRecord
{
    protected static string $resource = GlobalFrameResource::class;

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
