<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\Resources\PaymentReconciliationResource;
use App\Filament\SuperAdmin\Resources\GlobalPaymentReconciliationResource\Pages;

class GlobalPaymentReconciliationResource extends PaymentReconciliationResource
{
    public static function getNavigationGroup(): string
    {
        return 'Finance & Analytics';
    }

    public static function getNavigationSort(): int
    {
        return 4;
    }

    public static function getModelLabel(): string
    {
        return 'Rekonsiliasi Global';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Rekonsiliasi Pakasir';
    }

    public static function getPages(): array
    {
        return ['index' => Pages\ListGlobalPaymentReconciliations::route('/')];
    }
}
