<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\Payment;
use App\Models\Session;
use App\Services\PakasirReconciliationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PakasirReconciliationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config()->set('services.pakasir.slug', 'snaptechbooth');
        config()->set('services.pakasir.api_key', 'test-secret');
    }

    public function test_completed_gateway_payment_updates_local_payment_and_writes_history(): void
    {
        $payment = $this->createPayment('ORDER-PAID', 30000);
        Http::fake([
            'app.pakasir.com/*' => Http::response(['transaction' => [
                'order_id' => 'ORDER-PAID', 'amount' => 30000, 'status' => 'completed',
            ]]),
        ]);

        $result = app(PakasirReconciliationService::class)->reconcile($payment, 'manual');

        $this->assertSame('updated', $result?->result);
        $this->assertSame('paid', $payment->fresh()->status);
        $this->assertSame('completed', $payment->fresh()->gateway_status);
        $this->assertSame('active', $payment->session->fresh()->status);
        $this->assertDatabaseHas('payment_reconciliations', [
            'payment_id' => $payment->id, 'result' => 'updated', 'source' => 'manual',
        ]);
    }

    public function test_amount_mismatch_never_marks_payment_as_paid(): void
    {
        $payment = $this->createPayment('ORDER-MISMATCH', 30000);
        Http::fake([
            'app.pakasir.com/*' => Http::response(['transaction' => [
                'order_id' => 'ORDER-MISMATCH', 'amount' => 1000, 'status' => 'completed',
            ]]),
        ]);

        $result = app(PakasirReconciliationService::class)->reconcile($payment, 'scheduled');

        $this->assertSame('mismatch', $result?->result);
        $this->assertSame('pending', $payment->fresh()->status);
        $this->assertSame('mismatch', $payment->fresh()->reconciliation_status);
    }

    public function test_scheduled_command_reconciles_pending_payments(): void
    {
        $payment = $this->createPayment('ORDER-COMMAND', 25000);
        Http::fake([
            'app.pakasir.com/*' => Http::response(['transaction' => [
                'order_id' => 'ORDER-COMMAND', 'amount' => 25000, 'status' => 'pending',
            ]]),
        ]);

        $this->artisan('payments:reconcile-pakasir')->assertSuccessful();

        $this->assertSame('pending', $payment->fresh()->reconciliation_status);
        $this->assertDatabaseHas('payment_reconciliations', [
            'payment_id' => $payment->id, 'result' => 'pending', 'source' => 'scheduled',
        ]);
    }

    private function createPayment(string $orderId, int $amount): Payment
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Reconciliation', 'slug' => 'cafe-reconciliation-'.$orderId,
            'code' => 'REC-'.$orderId, 'status' => 'active',
        ]);
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'pending']);

        return Payment::create([
            'session_id' => $session->id,
            'xendit_payment_id' => $orderId,
            'amount' => $amount,
            'status' => 'pending',
        ]);
    }
}
