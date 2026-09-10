<?php

namespace App\Filament\SuperAdmin\Resources\GlobalWithdrawalResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalWithdrawalResource;
use Filament\Resources\Pages\ListRecords;

class ListGlobalWithdrawals extends ListRecords
{
    protected static string $resource = GlobalWithdrawalResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
