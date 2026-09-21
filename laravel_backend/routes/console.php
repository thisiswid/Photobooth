<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('photobooth:cleanup')->dailyAt('02:00');
Schedule::command('payments:settle-pakasir')->everyMinute()->withoutOverlapping();
Schedule::command('payments:reconcile-pakasir')->everyFiveMinutes()->withoutOverlapping();
Schedule::command('operations:scan-alerts')->everyFiveMinutes()->withoutOverlapping();
