<?php

namespace Database\Seeders;

use App\Models\Package;
use Illuminate\Database\Seeder;

class PackageSeeder extends Seeder
{
    public function run(): void
    {
        $packages = [
            [
                'name'        => 'Basic',
                'slug'        => 'basic',
                'photo_count' => 2,
                'print_count' => 1,
                'price'       => 25000,
                'description' => '2 foto digital + 1 cetak',
                'is_active'   => true,
                'sort_order'  => 1,
            ],
            [
                'name'        => 'Standard',
                'slug'        => 'standard',
                'photo_count' => 4,
                'print_count' => 2,
                'price'       => 45000,
                'description' => '4 foto digital + 2 cetak',
                'is_active'   => true,
                'sort_order'  => 2,
            ],
            [
                'name'        => 'Premium',
                'slug'        => 'premium',
                'photo_count' => 6,
                'print_count' => 3,
                'price'       => 65000,
                'description' => '6 foto digital + 3 cetak + animasi GIF',
                'is_active'   => true,
                'sort_order'  => 3,
            ],
        ];

        foreach ($packages as $data) {
            Package::updateOrCreate(['slug' => $data['slug']], $data);
        }
    }
}
