<?php

namespace App\Filament\Resources\VoucherRedemptionResource\Pages;

use App\Filament\Resources\VoucherRedemptionResource;
use Filament\Resources\Pages\ListRecords;

class ListVoucherRedemptions extends ListRecords
{
    protected static string $resource = VoucherRedemptionResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
