<?php

namespace Database\Seeders;

use App\Models\Cafe;
use App\Models\Event;
use App\Models\TimerSetting;
use Illuminate\Database\Seeder;

class TimerSettingSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // 1. Global Default Timer
        TimerSetting::updateOrCreate(
            ['cafe_id' => null, 'name' => 'Default Global Timer'],
            [
                'camera_countdown_seconds'      => 5,
                'session_timeout_seconds'       => 300,
                'payment_timeout_seconds'       => 120,
                'result_screen_timeout_seconds' => 60,
                'retake_timeout_seconds'        => 60,
                'is_active'                     => true,
            ]
        );

        // 2. Timer untuk masing-masing Cafe yang ada
        $cafes = Cafe::all();
        foreach ($cafes as $cafe) {
            $event = Event::where('cafe_id', $cafe->id)->where('active', true)->first();
            TimerSetting::updateOrCreate(
                [
                    'cafe_id' => $cafe->id,
                    'name'    => 'Standar Timer - ' . $cafe->name,
                ],
                [
                    'event_id'                      => $event?->id,
                    'camera_countdown_seconds'      => 5,
                    'session_timeout_seconds'       => 300,
                    'payment_timeout_seconds'       => 120,
                    'result_screen_timeout_seconds' => 60,
                    'retake_timeout_seconds'        => 60,
                    'is_active'                     => true,
                ]
            );
        }
    }
}
