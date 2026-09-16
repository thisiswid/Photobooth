<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\Payment;
use App\Models\Session;
use App\Models\User;
use App\Models\Withdrawal;
use App\Services\PakasirSettlementService;
use App\Services\WithdrawalPolicyService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SettlementAndWithdrawalPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_qris_settlement_is_due_at_noon_wib_on_the_next_day(): void
    {
        $paidAt = CarbonImmutable::parse('2026-09-15 08:12:00', 'Asia/Jakarta');

        $dueAt = PakasirSettlementService::dueAt($paidAt);

        $this->assertSame('2026-09-16 12:00:00', $dueAt->setTimezone('Asia/Jakarta')->format('Y-m-d H:i:s'));
        $this->assertSame('2026-09-16 05:00:00', $dueAt->format('Y-m-d H:i:s'));
    }

    public function test_due_qris_moves_from_pending_to_available_balance(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-09-15 10:00:00', 'Asia/Jakarta'));

        try {
            $cafe = $this->createCafe('SETTLEMENT');
            $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
            $payment = Payment::create([
                'session_id' => $session->id,
                'amount' => 30000,
                'payment_method' => 'qris',
                'status' => 'paid',
                'paid_at' => now(),
            ]);

            $this->assertSame('pending', $payment->settlement_status);
            $this->assertSame(29480, $cafe->fresh()->pending_settlement_balance);
            $this->assertSame(0, $cafe->fresh()->available_balance);

            $this->artisan('payments:settle-pakasir')->assertSuccessful();
            $this->assertSame('pending', $payment->fresh()->settlement_status);

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-09-16 12:00:00', 'Asia/Jakarta'));
            $this->artisan('payments:settle-pakasir')->assertSuccessful();

            $this->assertSame('settled', $payment->fresh()->settlement_status);
            $this->assertSame(0, $cafe->fresh()->pending_settlement_balance);
            $this->assertSame(29480, $cafe->fresh()->available_balance);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_automatic_withdrawal_fee_brackets_and_net_amount_are_calculated(): void
    {
        $this->assertSame(3000, WithdrawalPolicyService::adminFee('automatic', 15000));
        $this->assertSame(3000, WithdrawalPolicyService::adminFee('automatic', 4999999));
        $this->assertSame(5000, WithdrawalPolicyService::adminFee('automatic', 5000000));
        $this->assertSame(7000, WithdrawalPolicyService::adminFee('automatic', 10000000));
        $this->assertSame(0, WithdrawalPolicyService::adminFee('manual', 500000));

        $cafe = $this->createCafe('AUTO-FEE');
        $user = $this->createAdmin($cafe, 'auto-fee@example.test');
        $withdrawal = Withdrawal::create([
            'cafe_id' => $cafe->id,
            'user_id' => $user->id,
            'type' => 'automatic',
            'amount' => 5000000,
            'bank_name' => 'Bank Test',
            'bank_account_number' => '1234567890',
            'bank_account_holder' => 'Pemilik Cafe',
            'status' => 'pending',
        ]);

        $this->assertSame(5000, $withdrawal->admin_fee);
        $this->assertSame(4995000, $withdrawal->net_amount);
    }

    public function test_manual_and_automatic_request_windows_are_enforced(): void
    {
        $cafe = $this->createCafe('POLICY');
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
        Payment::create([
            'session_id' => $session->id,
            'amount' => 1000000,
            'payment_method' => 'qris',
            'status' => 'paid',
            'paid_at' => CarbonImmutable::parse('2026-09-01 10:00:00', 'Asia/Jakarta'),
        ]);

        $friday = CarbonImmutable::parse('2026-09-18 10:00:00', 'Asia/Jakarta');
        $monday = CarbonImmutable::parse('2026-09-21 10:00:00', 'Asia/Jakarta');
        $sunday = CarbonImmutable::parse('2026-09-20 10:00:00', 'Asia/Jakarta');

        $this->assertNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'manual', 500000, $friday));
        $this->assertNotNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'manual', 500000, $monday));
        $this->assertNotNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'manual', 500001, $friday));

        $this->assertNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'automatic', 15000, $monday));
        $this->assertNotNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'automatic', 14999, $monday));
        $this->assertNotNull(WithdrawalPolicyService::requestError($cafe->fresh(), 'automatic', 15000, $sunday));
        $this->assertNotNull(WithdrawalPolicyService::requestError(
            $cafe->fresh(),
            'automatic',
            15000,
            CarbonImmutable::parse('2026-09-21 16:00:00', 'Asia/Jakarta'),
        ));
    }

    public function test_manual_withdrawal_rejects_revenue_over_last_24_hour_limit(): void
    {
        $cafe = $this->createCafe('MANUAL-LIMIT');
        $friday = CarbonImmutable::parse('2026-09-18 10:00:00', 'Asia/Jakarta');
        $oldSession = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
        Payment::create([
            'session_id' => $oldSession->id,
            'amount' => 1000000,
            'payment_method' => 'qris',
            'status' => 'paid',
            'paid_at' => $friday->subDays(3),
            'settlement_status' => 'settled',
            'settled_at' => $friday->subDays(2)->setHour(12),
        ]);
        $recentSession = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
        Payment::create([
            'session_id' => $recentSession->id,
            'amount' => 150000,
            'payment_method' => 'qris',
            'status' => 'paid',
            'paid_at' => $friday->subHours(2),
        ]);

        $error = WithdrawalPolicyService::requestError($cafe->fresh(), 'manual', 50000, $friday);

        $this->assertSame(
            'Penarikan manual tidak tersedia karena penghasilan 24 jam terakhir melebihi Rp 100.000.',
            $error,
        );
    }

    public function test_manual_withdrawal_can_only_be_processed_on_saturday_morning(): void
    {
        $this->assertNull(WithdrawalPolicyService::manualProcessingError(
            CarbonImmutable::parse('2026-09-19 09:00:00', 'Asia/Jakarta'),
        ));
        $this->assertNotNull(WithdrawalPolicyService::manualProcessingError(
            CarbonImmutable::parse('2026-09-19 12:00:00', 'Asia/Jakarta'),
        ));
        $this->assertNotNull(WithdrawalPolicyService::manualProcessingError(
            CarbonImmutable::parse('2026-09-18 10:00:00', 'Asia/Jakarta'),
        ));
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

    private function createAdmin(Cafe $cafe, string $email): User
    {
        return User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin '.$cafe->code,
            'email' => $email,
            'password' => 'password',
            'role' => 'admin',
        ]);
    }
}
