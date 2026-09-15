<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_cafe_admin_sees_settlement_and_withdrawal_guidance_on_dashboard(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Dashboard',
            'slug' => 'cafe-dashboard',
            'code' => 'CAFE-DASHBOARD',
            'status' => 'active',
        ]);
        $admin = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin Dashboard',
            'email' => 'admin-dashboard@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);

        $this->actingAs($admin)
            ->get(route('filament.admin.pages.dashboard'))
            ->assertOk()
            ->assertSee('Panduan Saldo &amp; Penarikan Dana', false)
            ->assertSee('Settlement H+1, pukul 12.00 WIB')
            ->assertSee('Penarikan Manual')
            ->assertSee('Penarikan Otomatis')
            ->assertSee('Rp 500.000')
            ->assertSee('Rp 7.000');
    }
}
