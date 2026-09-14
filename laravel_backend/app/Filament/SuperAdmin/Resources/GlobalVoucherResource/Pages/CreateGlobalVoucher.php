<?php

namespace App\Filament\SuperAdmin\Resources\GlobalVoucherResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalVoucherResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGlobalVoucher extends CreateRecord
{
    protected static string $resource = GlobalVoucherResource::class;

    protected function getRedirectUrl(): string
    {
        return static::getResource()::getUrl('index');
    }
}
