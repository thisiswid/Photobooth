<?php

namespace Database\Seeders;

use App\Models\MasterFrame;
use Illuminate\Database\Seeder;

class MasterFrameSeeder extends Seeder
{
    public function run(): void
    {
        $masterFrames = [
            [
                'name'        => 'Strip Klasik Noir (4 Pose)',
                'category'    => 'General',
                'layout_type' => 'single',
                'pose_count'  => 4,
                'asset_url'   => 'frames/strip_klasik.png',
                'description' => 'Desain photo strip klasik dengan frame border hitam elegan dan aksen garis minimalis.',
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
                'name'        => 'Strip Modern Clean (4 Pose)',
                'category'    => 'Minimalist',
                'layout_type' => 'single',
                'pose_count'  => 4,
                'asset_url'   => 'frames/strip_modern.png',
                'description' => 'Gaya kontemporer bersih dengan layout simetris modern untuk cafe urban.',
                'layout_config' => [
                    'slots' => [
                        ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 380],
                        ['x' => 450, 'y' => 450, 'w' => 1100, 'h' => 380],
                        ['x' => 50, 'y' => 850, 'w' => 1100, 'h' => 380],
                        ['x' => 50, 'y' => 1250, 'w' => 1100, 'h' => 380],
                    ],
                ],
            ],
            [
                'name'        => 'Strip Vintage Sepia (3 Pose)',
                'category'    => 'Vintage',
                'layout_type' => 'single',
                'pose_count'  => 3,
                'asset_url'   => 'frames/strip_vintage.png',
                'description' => 'Nuansa vintage klasik dengan slot foto lebih besar untuk 3 pose dramatis.',
                'layout_config' => [
                    'slots' => [
                        ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
                    ],
                ],
            ],
            [
                'name'        => 'Warm Coffee House (4 Pose)',
                'category'    => 'Coffee & Cafe',
                'layout_type' => 'single',
                'pose_count'  => 4,
                'asset_url'   => 'frames/strip_coffee.png',
                'description' => 'Aksen warna kopi hangat dengan elemen cangkir kopi estetis khas cafe.',
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
                'name'        => 'Strip Golden Elegant (3 Pose)',
                'category'    => 'Wedding & Party',
                'layout_type' => 'single',
                'pose_count'  => 3,
                'asset_url'   => 'frames/strip_elegant.png',
                'description' => 'Desain mewah dengan aksen emas untuk perayaan, ulang tahun, dan pesta.',
                'layout_config' => [
                    'slots' => [
                        ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                        ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
                    ],
                ],
            ],
            [
                'name'        => 'Strip Pure Minimalis (4 Pose)',
                'category'    => 'Minimalist',
                'layout_type' => 'single',
                'pose_count'  => 4,
                'asset_url'   => 'frames/strip_minimalis.png',
                'description' => 'Border putih tipis estetik ala photo booth Korea (Korean Photo Strip).',
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

        foreach ($masterFrames as $item) {
            MasterFrame::updateOrCreate(
                ['name' => $item['name']],
                $item
            );
        }
    }
}
