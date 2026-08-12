<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('lumabooth:cleanup')->dailyAt('02:00');
