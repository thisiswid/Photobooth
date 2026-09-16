<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\Payment;
use App\Models\Session;
use App\Models\User;
use App\Services\PakasirFeeCalculator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PakasirFeeTest extends TestCase
{
    use RefreshDatabase;

    public function test_qris_fee_matches_pakasir_examples_and_threshold(): void
    {
        $this->assertSame(520, PakasirFeeCalculator::calculate(30000));
        $this->assertSame(485, PakasirFeeCalculator::calculate(25000));
        $this->assertSame(590, PakasirFeeCalculator::calculate(40000));
        $this->assertSame(317, PakasirFeeCalculator::calculate(1000));
        $this->assertSame(1045, PakasirFeeCalculator::calculate(105000));
        $this->assertSame(1050, PakasirFeeCalculator::calculate(105001));
    }

    public function test_payment_stores_gross_fee_and_net_amount(): void
    {
        $cafe = $this->createCafe('FEE-A');
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);

        $payment = Payment::create([
            'session_id' => $session->id,
            'amount' => 30000,
            'payment_method' => 'qris',
            'status' => 'paid',
        ]);

        $this->assertSame(30000, (int) $payment->amount);
        $this->assertSame(520, (int) $payment->provider_fee);
        $this->assertSame(29480, (int) $payment->net_amount);
        $this->assertSame(30000, $cafe->fresh()->total_revenue);
        $this->assertSame(520, $cafe->fresh()->pakasir_fee);
        $this->assertSame('pending', $payment->settlement_status);
        $this->assertSame(29480, $cafe->fresh()->pending_settlement_balance);
        $this->assertSame(0, $cafe->fresh()->available_balance);

        $payment->update(['settlement_due_at' => now()->subMinute()]);
        $this->artisan('payments:settle-pakasir')->assertSuccessful();

        $this->assertSame('settled', $payment->fresh()->settlement_status);
        $this->assertSame(0, $cafe->fresh()->pending_settlement_balance);
        $this->assertSame(29480, $cafe->fresh()->available_balance);
    }

    public function test_simulation_and_full_voucher_have_no_pakasir_fee(): void
    {
        $cafe = $this->createCafe('FEE-B');
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);

        $simulation = Payment::create([
            'session_id' => $session->id,
            'amount' => 25000,
            'payment_method' => 'qris',
            'status' => 'paid',
            'is_simulated' => true,
        ]);
        $voucher = Payment::create([
            'session_id' => $session->id,
            'amount' => 0,
            'payment_method' => 'voucher',
            'status' => 'paid',
        ]);

        $this->assertSame(0, (int) $simulation->provider_fee);
        $this->assertSame(25000, (int) $simulation->net_amount);
        $this->assertSame(0, (int) $voucher->provider_fee);
        $this->assertSame(0, (int) $voucher->net_amount);
        $this->assertSame(0, $cafe->fresh()->available_balance);
    }

    public function test_admin_and_super_admin_transaction_pages_show_fee_breakdown(): void
    {
        $cafe = $this->createCafe('FEE-C');
        $admin = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin Fee',
            'email' => 'admin-fee@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $superAdmin = User::create([
            'name' => 'Super Admin Fee',
            'email' => 'super-admin-fee@example.test',
            'password' => 'password',
            'role' => 'super_admin',
        ]);
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
        Payment::create(['session_id' => $session->id, 'amount' => 30000, 'status' => 'paid']);

        $this->actingAs($admin)
            ->get(route('filament.admin.resources.payments.index'))
            ->assertOk()
            ->assertSee('Biaya Layanan Pakasir')
            ->assertSee('Biaya Pakasir')
            ->assertSee('Neto Cafe')
            ->assertSee('- Rp 520');

        $this->flushSession();

        $this->actingAs($superAdmin)
            ->get(route('filament.super_admin.resources.global-payments.index'))
            ->assertOk()
            ->assertSee('Biaya Layanan Pakasir')
            ->assertSee('Biaya Pakasir')
            ->assertSee('Neto Cafe');
    }

    private function createCafe(string $code): Cafe
    {
        return Cafe::create([
            'name' => 'Cafe '.$code,
            'slug' => strtolower($code),
            'code' => $code,
            'status' => 'active',
        ]);
    }
}
