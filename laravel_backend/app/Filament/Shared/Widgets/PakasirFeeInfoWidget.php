<?php

namespace App\Filament\Shared\Widgets;

use Filament\Widgets\Widget;

class PakasirFeeInfoWidget extends Widget
{
    protected static bool $isLazy = false;

    protected string $view = 'filament.widgets.pakasir-fee-info-widget';

    protected int|string|array $columnSpan = 'full';
}
