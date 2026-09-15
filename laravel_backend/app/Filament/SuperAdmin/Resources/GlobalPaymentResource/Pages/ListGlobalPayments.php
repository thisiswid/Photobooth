<?php

namespace App\Filament\SuperAdmin\Resources\GlobalPaymentResource\Pages;

use App\Filament\Shared\Widgets\PakasirFeeInfoWidget;
use App\Filament\SuperAdmin\Resources\GlobalPaymentResource;
use Filament\Resources\Pages\ListRecords;

class ListGlobalPayments extends ListRecords
{
    protected static string $resource = GlobalPaymentResource::class;

    protected function getHeaderWidgets(): array
    {
        return [PakasirFeeInfoWidget::class];
    }
}
