<?php

namespace Database\Seeders;

use App\Models\Layout;
use Illuminate\Database\Seeder;

class LayoutSeeder extends Seeder
{
    public function run(): void
    {
        $layouts = [
            [
                'name'        => '2 Foto',
                'slug'        => '2-foto',
                'photo_count' => 2,
                'orientation' => 'portrait',
                'is_active'   => true,
                'config'      => json_encode([
                    'slots' => [
                        ['index' => 0, 'x' => 0.05, 'y' => 0.05, 'width' => 0.9, 'height' => 0.44],
                        ['index' => 1, 'x' => 0.05, 'y' => 0.51, 'width' => 0.9, 'height' => 0.44],
                    ],
                ]),
            ],
            [
                'name'        => '4 Foto',
                'slug'        => '4-foto',
                'photo_count' => 4,
                'orientation' => 'landscape',
                'is_active'   => true,
                'config'      => json_encode([
                    'slots' => [
                        ['index' => 0, 'x' => 0.03, 'y' => 0.03, 'width' => 0.46, 'height' => 0.44],
                        ['index' => 1, 'x' => 0.51, 'y' => 0.03, 'width' => 0.46, 'height' => 0.44],
                        ['index' => 2, 'x' => 0.03, 'y' => 0.53, 'width' => 0.46, 'height' => 0.44],
                        ['index' => 3, 'x' => 0.51, 'y' => 0.53, 'width' => 0.46, 'height' => 0.44],
                    ],
                ]),
            ],
            [
                'name'        => 'Photo Strip',
                'slug'        => 'photo-strip',
                'photo_count' => 4,
                'orientation' => 'portrait',
                'is_active'   => true,
                'config'      => json_encode([
                    'slots' => [
                        ['index' => 0, 'x' => 0.05, 'y' => 0.02, 'width' => 0.9, 'height' => 0.22],
                        ['index' => 1, 'x' => 0.05, 'y' => 0.26, 'width' => 0.9, 'height' => 0.22],
                        ['index' => 2, 'x' => 0.05, 'y' => 0.50, 'width' => 0.9, 'height' => 0.22],
                        ['index' => 3, 'x' => 0.05, 'y' => 0.74, 'width' => 0.9, 'height' => 0.22],
                    ],
                ]),
            ],
            [
                'name'        => 'Portrait',
                'slug'        => 'portrait',
                'photo_count' => 1,
                'orientation' => 'portrait',
                'is_active'   => true,
                'config'      => json_encode([
                    'slots' => [['index' => 0, 'x' => 0.05, 'y' => 0.05, 'width' => 0.9, 'height' => 0.9]],
                ]),
            ],
            [
                'name'        => 'Landscape',
                'slug'        => 'landscape',
                'photo_count' => 1,
                'orientation' => 'landscape',
                'is_active'   => true,
                'config'      => json_encode([
                    'slots' => [['index' => 0, 'x' => 0.05, 'y' => 0.05, 'width' => 0.9, 'height' => 0.9]],
                ]),
            ],
        ];

        foreach ($layouts as $data) {
            Layout::updateOrCreate(['slug' => $data['slug']], $data);
        }
    }
}
