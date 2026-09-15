<?php

namespace App\Filament\Resources\PaymentResource\Pages;

use App\Filament\Resources\PaymentResource;
use App\Filament\Shared\Widgets\PakasirFeeInfoWidget;
use Filament\Resources\Pages\ListRecords;

class ListPayments extends ListRecords
{
    protected static string $resource = PaymentResource::class;

    protected function getHeaderWidgets(): array
    {
        return [PakasirFeeInfoWidget::class];
    }
}
