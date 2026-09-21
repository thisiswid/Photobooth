<?php

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\Resources\OperationalAlertResource;
use App\Filament\SuperAdmin\Resources\GlobalOperationalAlertResource\Pages;

class GlobalOperationalAlertResource extends OperationalAlertResource
{
    public static function getNavigationGroup(): string
    {
        return 'Monitoring';
    }

    public static function getNavigationSort(): int
    {
        return 1;
    }

    public static function getModelLabel(): string
    {
        return 'Peringatan Global';
    }

    public static function getPluralModelLabel(): string
    {
        return 'Peringatan Operasional';
    }

    public static function getPages(): array
    {
        return ['index' => Pages\ListGlobalOperationalAlerts::route('/')];
    }
}
