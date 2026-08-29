<?php

namespace Database\Seeders;

use App\Models\Cafe;
use App\Models\Device;
use App\Models\Event;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Super Admin (Pihak Pertama / Platform Owner)
        User::updateOrCreate(
            ['email' => 'superadmin@photobooth.com'],
            [
                'name'     => 'Platform Super Admin',
                'email'    => 'superadmin@photobooth.com',
                'password' => Hash::make('password'),
                'role'     => 'super_admin',
                'cafe_id'  => null,
            ]
        );

        // 2. Initial Tenant / Cafe (Pihak Kedua)
        $cafe = Cafe::updateOrCreate(
            ['slug' => 'fakultas-kopi'],
            [
                'name'                     => 'Fakultas Kopi',
                'slug'                     => 'fakultas-kopi',
                'code'                     => 'FK-BOOT-001',
                'pic_name'                 => 'Budi Santoso',
                'pic_phone'                => '081234567890',
                'pic_email'                => 'owner@fakultaskopi.com',
                'address'                  => 'Jl. Margonda Raya No. 123, Depok',
                'status'                   => 'active',
                'subscription_end_at'      => now()->addYear(),
                'revenue_share_percentage' => 10.00,
                'notes'                    => 'Pilot cafe photobooth installation.',
            ]
        );

        // 3. Cafe Admin (Akun pengelola cafe)
        User::updateOrCreate(
            ['email' => 'admin@fakultaskopi.com'],
            [
                'name'     => 'Admin Fakultas Kopi',
                'email'    => 'admin@fakultaskopi.com',
                'password' => Hash::make('password'),
                'role'     => 'admin',
                'cafe_id'  => $cafe->id,
            ]
        );

        // Optional: admin@snaptechbooth.com / admin@fakultaskopi.com
        User::updateOrCreate(
            ['email' => 'admin@snaptechbooth.com'],
            [
                'name'     => 'Admin SnapTech',
                'email'    => 'admin@snaptechbooth.com',
                'password' => Hash::make('password'),
                'role'     => 'admin',
                'cafe_id'  => $cafe->id,
            ]
        );

        // 4. Link existing events and devices to this cafe
        Event::whereNull('cafe_id')->update(['cafe_id' => $cafe->id]);
        
        // 5. Initial Device for Fakultas Kopi
        Device::updateOrCreate(
            ['device_key' => 'FK-DEV-001'],
            [
                'cafe_id'    => $cafe->id,
                'name'       => 'Photobooth Utama (Lantai 1)',
                'device_key' => 'FK-DEV-001',
                'platform'   => 'android',
                'status'     => 'active',
            ]
        );
    }
}
