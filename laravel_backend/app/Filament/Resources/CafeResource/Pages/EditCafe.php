<?php

namespace App\Filament\Resources\CafeResource\Pages;

use App\Filament\Resources\CafeResource;
use Filament\Resources\Pages\EditRecord;

class EditCafe extends EditRecord
{
    protected static string $resource = CafeResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
