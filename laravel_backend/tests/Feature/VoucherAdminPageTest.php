<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VoucherAdminPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_cafe_admin_can_manage_only_own_vouchers_and_open_redemption_history(): void
    {
        [$cafeA, $adminA] = $this->cafeAndAdmin('Voucher A', 'voucher-a');
        [$cafeB] = $this->cafeAndAdmin('Voucher B', 'voucher-b');
        $voucherA = $this->voucher($cafeA, 'PROMOA');
        $voucherB = $this->voucher($cafeB, 'PROMOB');

        $this->actingAs($adminA)->get(route('filament.admin.resources.vouchers.index'))
            ->assertOk()->assertSee('PROMOA')->assertDontSee('PROMOB');
        $this->actingAs($adminA)->get(route('filament.admin.resources.vouchers.create'))->assertOk();
        $this->actingAs($adminA)->get(route('filament.admin.resources.vouchers.edit', $voucherA))->assertOk();
        $this->actingAs($adminA)->get(route('filament.admin.resources.vouchers.edit', $voucherB))->assertNotFound();
        $this->actingAs($adminA)->get(route('filament.admin.resources.voucher-redemptions.index'))->assertOk();
    }

    public function test_super_admin_can_manage_global_vouchers_and_open_global_history(): void
    {
        [$cafe] = $this->cafeAndAdmin('Voucher Mitra', 'voucher-mitra');
        $voucher = $this->voucher($cafe, 'GLOBAL10');
        $superAdmin = User::create([
            'name' => 'Super Admin Voucher',
            'email' => 'super-voucher@example.test',
            'password' => 'password',
            'role' => 'super_admin',
        ]);

        $this->actingAs($superAdmin)->get(route('filament.super_admin.resources.global-vouchers.index'))
            ->assertOk()->assertSee('GLOBAL10');
        $this->actingAs($superAdmin)->get(route('filament.super_admin.resources.global-vouchers.create'))->assertOk();
        $this->actingAs($superAdmin)->get(route('filament.super_admin.resources.global-vouchers.edit', $voucher))->assertOk();
        $this->actingAs($superAdmin)->get(route('filament.super_admin.resources.global-voucher-redemptions.index'))->assertOk();
    }

    public function test_system_generates_unique_voucher_code_when_code_is_empty(): void
    {
        [$cafe] = $this->cafeAndAdmin('Voucher Acak', 'voucher-acak');

        $first = $this->voucher($cafe, '');
        $second = $this->voucher($cafe, '');

        $this->assertMatchesRegularExpression('/^STB-[A-Z0-9]{8}$/', $first->code);
        $this->assertNotSame($first->code, $second->code);
    }

    private function cafeAndAdmin(string $name, string $slug): array
    {
        $cafe = Cafe::create(['name' => $name, 'slug' => $slug, 'code' => strtoupper($slug), 'status' => 'active']);
        $admin = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin '.$name,
            'email' => $slug.'@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);

        return [$cafe, $admin];
    }

    private function voucher(Cafe $cafe, string $code): Voucher
    {
        return Voucher::create([
            'cafe_id' => $cafe->id,
            'name' => $code,
            'code' => $code,
            'type' => 'fixed',
            'value' => 10000,
            'is_active' => true,
        ]);
    }
}
