<?php

namespace App\Filament\Widgets;

use Filament\Widgets\Widget;

class PakasirSettlementInfoWidget extends Widget
{
    protected static bool $isLazy = false;

    protected string $view = 'filament.widgets.pakasir-settlement-info-widget';

    protected int|string|array $columnSpan = 'full';

    public static function getSort(): int
    {
        return 2;
    }
}
