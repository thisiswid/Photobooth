<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\Event;
use App\Models\Frame;
use App\Models\Payment;
use App\Models\Session;
use App\Models\User;
use App\Models\Withdrawal;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Tests\TestCase;

class DeviceLicenseAndFrameIsolationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutMiddleware(ThrottleRequests::class);
    }

    public function test_cafe_license_cannot_activate_more_app_installations_than_its_limit(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Satu',
            'slug' => 'cafe-satu',
            'code' => 'PB-CAFE1',
            'status' => 'active',
            'device_limit' => 1,
        ]);

        $this->postJson('/api/devices/activate', [
            'device_key' => $cafe->code,
            'installation_id' => '11111111-1111-4111-8111-111111111111',
            'platform' => 'android',
        ])->assertOk();

        $this->postJson('/api/devices/activate', [
            'device_key' => $cafe->code,
            'installation_id' => '22222222-2222-4222-8222-222222222222',
            'platform' => 'android',
        ])->assertStatus(409);

        $this->assertSame(1, $cafe->devices()->whereNotNull('installation_id')->count());
    }

    public function test_device_config_only_contains_frames_from_its_own_cafe(): void
    {
        $cafeA = Cafe::create(['name' => 'Cafe A', 'slug' => 'cafe-a', 'code' => 'PB-A', 'status' => 'active']);
        $cafeB = Cafe::create(['name' => 'Cafe B', 'slug' => 'cafe-b', 'code' => 'PB-B', 'status' => 'active']);
        $eventA = Event::create(['cafe_id' => $cafeA->id, 'name' => 'Event A', 'active' => true]);
        $eventB = Event::create(['cafe_id' => $cafeB->id, 'name' => 'Event B', 'active' => true]);
        Frame::create(['event_id' => $eventA->id, 'name' => 'Frame A', 'asset_url' => 'frames/a.png', 'active' => true]);
        Frame::create(['event_id' => $eventB->id, 'name' => 'Frame B', 'asset_url' => 'frames/b.png', 'active' => true]);

        $installationId = '33333333-3333-4333-8333-333333333333';
        $activation = $this->postJson('/api/devices/activate', [
            'device_key' => $cafeA->code,
            'installation_id' => $installationId,
            'platform' => 'android',
        ])->assertOk();

        $deviceKey = $activation->json('data.device.device_key');
        $this->getJson('/api/devices/' . $deviceKey . '/config?installation_id=' . $installationId)
            ->assertOk()
            ->assertJsonCount(1, 'data.frames')
            ->assertJsonPath('data.frames.0.name', 'Frame A');
    }

    public function test_event_frame_endpoint_never_falls_back_to_another_tenant(): void
    {
        $cafeA = Cafe::create(['name' => 'Cafe A', 'slug' => 'event-a', 'code' => 'EV-A', 'status' => 'active']);
        $cafeB = Cafe::create(['name' => 'Cafe B', 'slug' => 'event-b', 'code' => 'EV-B', 'status' => 'active']);
        $emptyEvent = Event::create(['cafe_id' => $cafeA->id, 'name' => 'Kosong', 'active' => true]);
        $otherEvent = Event::create(['cafe_id' => $cafeB->id, 'name' => 'Milik B', 'active' => true]);
        Frame::create(['event_id' => $otherEvent->id, 'name' => 'Rahasia B', 'asset_url' => 'frames/b.png', 'active' => true]);

        $this->getJson('/api/events/' . $emptyEvent->id . '/frames')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_withdrawal_balance_uses_full_cafe_revenue_without_percentage_deduction(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Saldo',
            'slug' => 'cafe-saldo',
            'code' => 'PB-SALDO',
            'status' => 'active',
            'revenue_share_percentage' => 25,
        ]);
        $user = User::create([
            'cafe_id' => $cafe->id,
            'name' => 'Admin Cafe',
            'email' => 'saldo@example.test',
            'password' => 'password',
            'role' => 'admin',
        ]);
        $session = Session::create(['cafe_id' => $cafe->id, 'status' => 'finished']);
        Payment::create(['session_id' => $session->id, 'amount' => 100000, 'status' => 'paid']);

        foreach ([['approved', 20000], ['pending', 30000], ['rejected', 40000]] as [$status, $amount]) {
            Withdrawal::create([
                'cafe_id' => $cafe->id,
                'user_id' => $user->id,
                'amount' => $amount,
                'bank_name' => 'Bank Test',
                'bank_account_number' => '123456789',
                'bank_account_holder' => 'Admin Cafe',
                'status' => $status,
            ]);
        }

        $cafe->refresh();
        $this->assertSame(100000, $cafe->total_revenue);
        $this->assertSame(0, $cafe->platform_fee);
        $this->assertSame(100000, $cafe->net_revenue);
        $this->assertSame(50000, $cafe->available_balance);
    }

    public function test_simulated_payment_requires_cafe_toggle_and_never_enters_real_balance(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Simulasi',
            'slug' => 'cafe-simulasi',
            'code' => 'PB-SIM',
            'status' => 'active',
            'payment_simulation_enabled' => false,
        ]);
        $device = $cafe->devices()->first();
        $device->update(['installation_id' => '44444444-4444-4444-8444-444444444444']);
        $session = Session::create(['cafe_id' => $cafe->id, 'device_id' => $device->id, 'status' => 'pending']);
        $payment = Payment::create(['session_id' => $session->id, 'amount' => 25000, 'status' => 'pending']);
        $credentials = [
            'device_key' => $device->device_key,
            'installation_id' => $device->installation_id,
        ];

        $this->postJson("/api/payments/{$payment->id}/simulate-paid", $credentials)->assertForbidden();

        $cafe->update(['payment_simulation_enabled' => true]);
        $this->postJson("/api/payments/{$payment->id}/simulate-paid", $credentials)
            ->assertOk()
            ->assertJsonPath('data.is_simulated', true);

        $payment->refresh();
        $cafe->refresh();
        $this->assertTrue($payment->is_simulated);
        $this->assertSame(0, $cafe->total_revenue);
        $this->assertSame(25000, $cafe->simulation_revenue);
        $this->assertSame(0, $cafe->available_balance);
    }

    public function test_other_cafe_device_cannot_simulate_a_payment(): void
    {
        $cafeA = Cafe::create(['name' => 'Cafe A', 'slug' => 'sim-a', 'code' => 'SIM-A', 'status' => 'active', 'payment_simulation_enabled' => true]);
        $cafeB = Cafe::create(['name' => 'Cafe B', 'slug' => 'sim-b', 'code' => 'SIM-B', 'status' => 'active', 'payment_simulation_enabled' => true]);
        $deviceA = $cafeA->devices()->first();
        $deviceB = $cafeB->devices()->first();
        $deviceA->update(['installation_id' => '55555555-5555-4555-8555-555555555555']);
        $deviceB->update(['installation_id' => '66666666-6666-4666-8666-666666666666']);
        $session = Session::create(['cafe_id' => $cafeA->id, 'device_id' => $deviceA->id, 'status' => 'pending']);
        $payment = Payment::create(['session_id' => $session->id, 'amount' => 25000, 'status' => 'pending']);

        $this->postJson("/api/payments/{$payment->id}/simulate-paid", [
            'device_key' => $deviceB->device_key,
            'installation_id' => $deviceB->installation_id,
        ])->assertForbidden();

        $this->assertSame('pending', $payment->fresh()->status);
    }

    public function test_other_cafe_device_cannot_track_a_payment(): void
    {
        $cafeA = Cafe::create(['name' => 'Cafe Track A', 'slug' => 'track-a', 'code' => 'TRACK-A', 'status' => 'active']);
        $cafeB = Cafe::create(['name' => 'Cafe Track B', 'slug' => 'track-b', 'code' => 'TRACK-B', 'status' => 'active']);
        $deviceA = $cafeA->devices()->first();
        $deviceB = $cafeB->devices()->first();
        $deviceA->update(['installation_id' => '77777777-7777-4777-8777-777777777777']);
        $deviceB->update(['installation_id' => '88888888-8888-4888-8888-888888888888']);
        $session = Session::create(['cafe_id' => $cafeA->id, 'device_id' => $deviceA->id, 'status' => 'pending']);
        $payment = Payment::create(['session_id' => $session->id, 'amount' => 25000, 'status' => 'pending']);

        $this->getJson("/api/payments/{$payment->id}/status?device_key={$deviceB->device_key}&installation_id={$deviceB->installation_id}")
            ->assertForbidden();

        $this->getJson("/api/payments/{$payment->id}/status?device_key={$deviceA->device_key}&installation_id={$deviceA->installation_id}")
            ->assertOk()
            ->assertJsonPath('data.payment_id', $payment->id);
    }

    public function test_client_error_log_accepts_a_non_numeric_device_label(): void
    {
        $this->postJson('/api/logs', [
            'device_id' => 'Tablet-Photobooth-1',
            'category' => 'network',
            'level' => 'critical',
            'title' => 'Network Error HTTP 500',
            'message' => 'Aktivasi perangkat gagal.',
            'context' => ['endpoint' => 'POST /devices/activate'],
        ])->assertCreated();

        $this->assertDatabaseHas('error_logs', [
            'device_id' => 'Tablet-Photobooth-1',
            'cafe_id' => null,
        ]);
    }
}
