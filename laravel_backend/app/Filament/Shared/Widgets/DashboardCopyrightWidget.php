<?php

namespace App\Filament\Shared\Widgets;

use Filament\Widgets\Widget;

class DashboardCopyrightWidget extends Widget
{
    protected static bool $isLazy = false;

    protected string $view = 'filament.widgets.dashboard-copyright-widget';

    protected int|string|array $columnSpan = 'full';

    public static function getSort(): int
    {
        return 1000;
    }
}
