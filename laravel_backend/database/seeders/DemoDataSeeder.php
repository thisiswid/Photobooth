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
            ['name' => 'SnapTech Demo Event'],
            [
                'description' => 'Demo event untuk SnapTech Photobooth',
                'starts_at'   => now(),
                'ends_at'     => now()->addMonths(6),
                'active'      => true,
            ]
        );

        // --------------------------------------------------------
        // Demo Frames (6 photo strip designs)
        // --------------------------------------------------------
        $frames = [
            [
                'name'       => 'Strip Klasik',
                'asset_url'  => 'frames/strip_klasik.png',
                'pose_count' => 4,
                'layout_config' => [
                    'slots' => [
                        ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 367],
                        ['x' => 50, 'y' => 447, 'w' => 1100, 'h' => 367],
                        ['x' => 50, 'y' => 844, 'w' => 1100, 'h' => 367],
                        ['x' => 50, 'y' => 1241, 'w' => 1100, 'h' => 367],
                    ],
                ],
            ],
            [
                'name'       => 'Strip Modern',
                'asset_url'  => 'frames/strip_modern.png',
                'pose_count' => 4,
                'layout_config' => [
                    'slots' => [
                        ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 380],
                        ['x' => 50, 'y' => 450, 'w' => 1100, 'h' => 380],
                        ['x' => 50, 'y' => 850, 'w' => 1100, 'h' => 380],
                        ['x' => 50, 'y' => 1250, 'w' => 1100, 'h' => 380],
                    ],
                ],
            ],
            [
                'name'       => 'Strip Vintage',
                'asset_url'  => 'frames/strip_vintage.png',
                'pose_count' => 3,
                'layout_config' => [
                    'slots' => [
                        ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
                    ],
                ],
            ],
            [
                'name'       => 'Strip Coffee',
                'asset_url'  => 'frames/strip_coffee.png',
                'pose_count' => 4,
                'layout_config' => [
                    'slots' => [
                        ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 368],
                        ['x' => 50, 'y' => 443, 'w' => 1100, 'h' => 368],
                        ['x' => 50, 'y' => 836, 'w' => 1100, 'h' => 368],
                        ['x' => 50, 'y' => 1229, 'w' => 1100, 'h' => 368],
                    ],
                ],
            ],
            [
                'name'       => 'Strip Elegant',
                'asset_url'  => 'frames/strip_elegant.png',
                'pose_count' => 3,
                'layout_config' => [
                    'slots' => [
                        ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
                    ],
                ],
            ],
            [
                'name'       => 'Strip Minimalis',
                'asset_url'  => 'frames/strip_minimalis.png',
                'pose_count' => 4,
                'layout_config' => [
                    'slots' => [
                        ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 377],
                        ['x' => 50, 'y' => 451, 'w' => 1100, 'h' => 377],
                        ['x' => 50, 'y' => 852, 'w' => 1100, 'h' => 377],
                        ['x' => 50, 'y' => 1253, 'w' => 1100, 'h' => 377],
                    ],
                ],
            ],
        ];

        foreach ($frames as $f) {
            Frame::updateOrCreate(
                ['name' => $f['name'], 'event_id' => $event->id],
                [
                    'asset_url'     => $f['asset_url'],
                    'pose_count'    => $f['pose_count'],
                    'layout_config' => $f['layout_config'],
                    'active'        => true,
                ]
            );
        }

        // --------------------------------------------------------
        // Demo Filters (7 photo filters with parameters)
        // --------------------------------------------------------
        $filters = [
            [
                'name'          => 'Original',
                'thumbnail_url' => 'filters/filter_original.png',
                'parameters'    => json_encode(['type' => 'none']),
                'sort_order'    => 1,
            ],
            [
                'name'          => 'B&W',
                'thumbnail_url' => 'filters/filter_bw.png',
                'parameters'    => json_encode(['type' => 'grayscale']),
                'sort_order'    => 2,
            ],
            [
                'name'          => 'Warm',
                'thumbnail_url' => 'filters/filter_warm.png',
                'parameters'    => json_encode(['type' => 'colorize', 'r' => 25, 'g' => 10, 'b' => 0, 'brightness' => 10]),
                'sort_order'    => 3,
            ],
            [
                'name'          => 'Cool',
                'thumbnail_url' => 'filters/filter_cool.png',
                'parameters'    => json_encode(['type' => 'colorize', 'r' => -10, 'g' => 0, 'b' => 25, 'brightness' => 5]),
                'sort_order'    => 4,
            ],
            [
                'name'          => 'Vintage',
                'thumbnail_url' => 'filters/filter_vintage.png',
                'parameters'    => json_encode(['type' => 'sepia', 'intensity' => 80]),
                'sort_order'    => 5,
            ],
            [
                'name'          => 'High Contrast',
                'thumbnail_url' => 'filters/filter_high_contrast.png',
                'parameters'    => json_encode(['type' => 'contrast', 'level' => 30]),
                'sort_order'    => 6,
            ],
            [
                'name'          => 'Soft Glow',
                'thumbnail_url' => 'filters/filter_soft_glow.png',
                'parameters'    => json_encode(['type' => 'soft', 'blur' => 1, 'brightness' => 15]),
                'sort_order'    => 7,
            ],
        ];

        foreach ($filters as $f) {
            Filter::updateOrCreate(
                ['name' => $f['name'], 'event_id' => $event->id],
                [
                    'thumbnail_url' => $f['thumbnail_url'],
                    'parameters'    => $f['parameters'],
                    'sort_order'    => $f['sort_order'],
                    'active'        => true,
                ]
            );
        }

        // --------------------------------------------------------
        // Welcome Screen
        // --------------------------------------------------------
        ScreenConfig::updateOrCreate(
            ['screen_type' => 'welcome', 'event_id' => $event->id, 'status' => 'active'],
            [
                'title'       => 'Selamat Datang!',
                'description' => 'Abadikan momen spesialmu bersama kami.',
                'button_text' => 'Mulai',
                'version'     => 1,
            ]
        );

        // --------------------------------------------------------
        // Tutorial Screen
        // --------------------------------------------------------
        ScreenConfig::updateOrCreate(
            ['screen_type' => 'tutorial', 'event_id' => $event->id, 'status' => 'active'],
            [
                'title'       => 'Cara Menggunakan Photobooth',
                'description' => 'Ikuti langkah-langkah berikut.',
                'button_text' => 'Lanjut',
                'version'     => 1,
            ]
        );
    }
}
