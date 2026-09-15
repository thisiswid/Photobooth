<?php

namespace App\Filament\SuperAdmin\Resources\GlobalVoucherResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalVoucherResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListGlobalVouchers extends ListRecords
{
    protected static string $resource = GlobalVoucherResource::class;

    protected function getHeaderActions(): array
    {
        return [CreateAction::make()->label('Buat Voucher Cafe')];
    }
}
