<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\User;
use App\Models\Withdrawal;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WithdrawalPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_cafe_admin_can_open_own_withdrawal_detail_and_see_settlement_information(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Sendiri',
            'slug' => 'cafe-sendiri',
            'code' => 'CAFE-SENDIRI',
            'status' => 'active',
        ]);
        $admin = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin Cafe',
            'email' => 'admin-cafe@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $withdrawal = $this->createWithdrawal($cafe, $admin);

        $this->actingAs($admin)
            ->get(route('filament.admin.resources.withdrawals.index'))
            ->assertOk()
            ->assertSee('Settlement H+1, pukul 12.00 WIB');

        $this->actingAs($admin)
            ->get(route('filament.admin.resources.withdrawals.view', $withdrawal))
            ->assertOk()
            ->assertSee($withdrawal->reference_no);
    }

    public function test_cafe_admin_cannot_open_another_cafes_withdrawal(): void
    {
        $cafeA = Cafe::create(['name' => 'Cafe A', 'slug' => 'wd-a', 'code' => 'WD-A', 'status' => 'active']);
        $cafeB = Cafe::create(['name' => 'Cafe B', 'slug' => 'wd-b', 'code' => 'WD-B', 'status' => 'active']);
        $adminA = User::create([
            'cafe_id' => $cafeA->id,
            'name' => 'Admin A',
            'email' => 'admin-a@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $adminB = User::create([
            'cafe_id' => $cafeB->id,
            'name' => 'Admin B',
            'email' => 'admin-b@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $withdrawalB = $this->createWithdrawal($cafeB, $adminB);

        $this->actingAs($adminA)
            ->get(route('filament.admin.resources.withdrawals.view', $withdrawalB))
            ->assertNotFound();
    }

    public function test_super_admin_can_open_withdrawal_detail_and_see_settlement_information(): void
    {
        $cafe = Cafe::create(['name' => 'Cafe Mitra', 'slug' => 'cafe-mitra', 'code' => 'MITRA', 'status' => 'active']);
        $admin = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin Mitra',
            'email' => 'admin-mitra@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'super-admin@example.test',
            'password' => 'password',
            'role' => 'super_admin',
        ]);
        $withdrawal = $this->createWithdrawal($cafe, $admin);

        $this->actingAs($superAdmin)
            ->get(route('filament.super_admin.resources.global-withdrawals.index'))
            ->assertOk()
            ->assertSee('Settlement H+1, pukul 12.00 WIB');

        $this->actingAs($superAdmin)
            ->get(route('filament.super_admin.resources.global-withdrawals.view', $withdrawal))
            ->assertOk()
            ->assertSee($withdrawal->reference_no);
    }

    private function createWithdrawal(Cafe $cafe, User $user): Withdrawal
    {
        return Withdrawal::create([
            'cafe_id' => $cafe->id,
            'user_id' => $user->id,
            'amount' => 50000,
            'bank_name' => 'Bank Test',
            'bank_account_number' => '1234567890',
            'bank_account_holder' => $user->name,
            'status' => 'pending',
        ]);
    }
}
