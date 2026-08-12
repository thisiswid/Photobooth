<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@fakultaskopi.com'],
            [
                'name'     => 'Admin Fakultas Kopi',
                'password' => Hash::make('photobooth2024!'),
                'role'     => 'admin',
                'is_active' => true,
            ]
        );
    }
}
