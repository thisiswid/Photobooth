<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFilterResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFilterResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalFilter extends EditRecord
{
    protected static string $resource = GlobalFilterResource::class;

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
