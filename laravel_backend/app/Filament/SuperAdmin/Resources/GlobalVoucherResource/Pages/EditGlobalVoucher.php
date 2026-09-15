<?php

namespace App\Filament\SuperAdmin\Resources\GlobalVoucherResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalVoucherResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditGlobalVoucher extends EditRecord
{
    protected static string $resource = GlobalVoucherResource::class;

    protected function getHeaderActions(): array
    {
        return [DeleteAction::make()->visible(fn () => $this->record->redemptions()->doesntExist())];
    }

    protected function getRedirectUrl(): string
    {
        return static::getResource()::getUrl('index');
    }
}
