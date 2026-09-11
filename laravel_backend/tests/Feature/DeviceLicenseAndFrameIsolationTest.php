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
}
