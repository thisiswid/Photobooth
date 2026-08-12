<?php

namespace Database\Seeders;

use App\Models\Event;
use App\Models\Filter;
use App\Models\Frame;
use App\Models\ScreenConfig;
use Illuminate\Database\Seeder;

class DemoDataSeeder extends Seeder
{
    public function run(): void
    {
        $event = Event::updateOrCreate(
            ['name' => 'LumaBooth Demo Event'],
            [
                'description' => 'Demo event untuk LumaBooth',
                'starts_at'   => now(),
                'ends_at'     => now()->addMonths(6),
                'active'      => true,
            ]
        );

        // Demo frames
        foreach (['Frame Klasik', 'Frame Modern', 'Frame Vintage'] as $i => $name) {
            Frame::updateOrCreate(
                ['name' => $name, 'event_id' => $event->id],
                ['active' => true]
            );
        }

        // Demo filters
        $filters = [
            ['name' => 'Original',   'sort_order' => 1],
            ['name' => 'B&W',        'sort_order' => 2],
            ['name' => 'Warm',       'sort_order' => 3],
            ['name' => 'Cool',       'sort_order' => 4],
            ['name' => 'Vintage',    'sort_order' => 5],
        ];
        foreach ($filters as $f) {
            Filter::updateOrCreate(
                ['name' => $f['name'], 'event_id' => $event->id],
                ['sort_order' => $f['sort_order'], 'active' => true]
            );
        }

        // Welcome screen
        ScreenConfig::updateOrCreate(
            ['screen_type' => 'welcome', 'event_id' => $event->id, 'status' => 'active'],
            [
                'title'       => 'Selamat Datang di LumaBooth!',
                'description' => 'Abadikan momen spesialmu bersama kami.',
                'button_text' => 'Mulai',
                'version'     => 1,
            ]
        );

        // Tutorial screen
        ScreenConfig::updateOrCreate(
            ['screen_type' => 'tutorial', 'event_id' => $event->id, 'status' => 'active'],
            [
                'title'       => 'Cara Menggunakan LumaBooth',
                'description' => 'Ikuti langkah-langkah berikut.',
                'button_text' => 'Lanjut',
                'version'     => 1,
            ]
        );
    }
}
