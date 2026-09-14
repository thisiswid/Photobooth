<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\PakasirSetting;
use App\Models\Payment;
use App\Models\Voucher;
use App\Services\PakasirService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class VoucherPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutMiddleware(ThrottleRequests::class);
    }

    public function test_full_voucher_activates_session_without_creating_qris(): void
    {
        [$cafe, $device, $credentials] = $this->activeDevice('FREE-CAFE');
        $voucher = Voucher::create([
            'cafe_id' => $cafe->id,
            'name' => 'Gratis Foto',
            'code' => 'FREE100',
            'type' => 'full',
            'quota' => 5,
            'per_device_limit' => 1,
            'is_active' => true,
        ]);

        Http::fake(fn () => throw new \RuntimeException('Pakasir tidak boleh dipanggil untuk voucher gratis.'));

        $response = $this->postJson('/api/payments', [...$credentials, 'voucher_code' => 'free100'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.amount', 0)
            ->assertJsonPath('data.payment_method', 'voucher')
            ->assertJsonPath('data.voucher_code', 'FREE100')
            ->assertJsonPath('data.qr_string', null);

        $this->assertDatabaseHas('payments', [
            'id' => $response->json('data.payment_id'),
            'voucher_id' => $voucher->id,
            'original_amount' => 25000,
            'discount_amount' => 25000,
            'amount' => 0,
            'status' => 'paid',
        ]);
        $this->assertDatabaseHas('photo_sessions', ['id' => $response->json('data.session_id'), 'status' => 'active']);
        $this->assertSame(1, $voucher->fresh()->used_count);
        $this->assertSame(0, $cafe->fresh()->total_revenue);
    }

    public function test_fixed_voucher_reduces_the_amount_sent_to_pakasir(): void
    {
        [$cafe, $device, $credentials] = $this->activeDevice('DISC-CAFE');
        PakasirSetting::create([
            'project_slug' => 'voucher-test',
            'api_key' => 'voucher-secret',
            'is_enabled' => true,
        ]);
        Voucher::create([
            'cafe_id' => $cafe->id,
            'name' => 'Potongan Sepuluh Ribu',
            'code' => 'HEMAT10',
            'type' => 'fixed',
            'value' => 10000,
            'quota' => 10,
            'is_active' => true,
        ]);
        Http::fake([
            'app.pakasir.com/*' => Http::response(['payment' => [
                'payment_number' => '000201010212TESTQR',
                'total_payment' => 15000,
                'fee' => 0,
                'expired_at' => now()->addMinutes(15)->toIso8601String(),
            ]]),
        ]);

        $response = $this->postJson('/api/payments', [...$credentials, 'voucher_code' => 'HEMAT10'])
            ->assertCreated()
            ->assertJsonPath('data.original_amount', 25000)
            ->assertJsonPath('data.discount_amount', 10000)
            ->assertJsonPath('data.amount', 15000)
            ->assertJsonPath('data.payment_method', 'qris_voucher');

        Http::assertSent(fn ($request) => $request['amount'] === 15000);

        PakasirService::markPaid(Payment::findOrFail($response->json('data.payment_id')));
        $this->assertDatabaseHas('voucher_redemptions', [
            'payment_id' => $response->json('data.payment_id'),
            'status' => 'used',
        ]);
        $this->assertSame(1, Voucher::where('code', 'HEMAT10')->first()->used_count);
        $this->assertSame(15000, $cafe->fresh()->total_revenue);
    }

    public function test_voucher_from_another_cafe_is_rejected(): void
    {
        [$cafeA, $deviceA, $credentialsA] = $this->activeDevice('CAFE-A');
        [$cafeB] = $this->activeDevice('CAFE-B');
        Voucher::create([
            'cafe_id' => $cafeB->id,
            'name' => 'Voucher Cafe B',
            'code' => 'KHUSUSB',
            'type' => 'full',
            'is_active' => true,
        ]);

        $this->postJson('/api/vouchers/validate', [...$credentialsA, 'voucher_code' => 'KHUSUSB'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('voucher_code');
    }

    public function test_percentage_voucher_respects_its_maximum_discount(): void
    {
        [$cafe, $device, $credentials] = $this->activeDevice('PERCENT-CAFE');
        Voucher::create([
            'cafe_id' => $cafe->id,
            'name' => 'Diskon Dua Puluh Persen',
            'code' => 'PCT20',
            'type' => 'percentage',
            'value' => 20,
            'max_discount' => 3000,
            'is_active' => true,
        ]);

        $this->postJson('/api/vouchers/validate', [...$credentials, 'voucher_code' => 'PCT20'])
            ->assertOk()
            ->assertJsonPath('data.original_amount', 25000)
            ->assertJsonPath('data.discount_amount', 3000)
            ->assertJsonPath('data.final_amount', 22000);
    }

    public function test_per_device_limit_is_enforced_after_full_voucher_use(): void
    {
        [$cafe, $device, $credentials] = $this->activeDevice('LIMIT-CAFE');
        Voucher::create([
            'cafe_id' => $cafe->id,
            'name' => 'Sekali Pakai',
            'code' => 'ONCE',
            'type' => 'full',
            'quota' => 10,
            'per_device_limit' => 1,
            'is_active' => true,
        ]);

        $this->postJson('/api/payments', [...$credentials, 'voucher_code' => 'ONCE'])->assertCreated();
        $this->postJson('/api/payments', [...$credentials, 'voucher_code' => 'ONCE'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('voucher_code');
    }

    private function activeDevice(string $code): array
    {
        $cafe = Cafe::create([
            'name' => $code,
            'slug' => strtolower($code),
            'code' => $code,
            'status' => 'active',
            'session_price' => 25000,
        ]);
        $device = $cafe->devices()->first();
        $installationId = fake()->uuid();
        $device->update(['installation_id' => $installationId, 'status' => 'active']);

        return [$cafe, $device, [
            'device_key' => $device->device_key,
            'installation_id' => $installationId,
        ]];
    }
}
