<?php

namespace App\Filament\SuperAdmin\Resources\GlobalVoucherRedemptionResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalVoucherRedemptionResource;
use Filament\Resources\Pages\ListRecords;

class ListGlobalVoucherRedemptions extends ListRecords
{
    protected static string $resource = GlobalVoucherRedemptionResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
