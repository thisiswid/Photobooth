<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('photobooth:cleanup')->dailyAt('02:00');
