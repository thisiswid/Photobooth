<?php

namespace App\Filament\SuperAdmin\Resources\CafeResource\Pages;

use App\Filament\SuperAdmin\Resources\CafeResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditCafe extends EditRecord
{
    protected static string $resource = CafeResource::class;

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
