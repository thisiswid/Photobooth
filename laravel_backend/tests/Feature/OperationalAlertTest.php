<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\OperationalAlert;
use App\Models\User;
use App\Services\OperationalAlertService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OperationalAlertTest extends TestCase
{
    use RefreshDatabase;

    public function test_offline_device_alert_is_deduplicated_notified_and_resolved(): void
    {
        $cafe = Cafe::create([
            'name' => 'Cafe Alert', 'slug' => 'cafe-alert', 'code' => 'ALERT',
            'status' => 'active', 'device_limit' => 2,
        ]);
        $admin = User::create([
            'cafe_id' => $cafe->id, 'name' => 'Admin Alert', 'email' => 'alert@example.test',
            'password' => 'password', 'role' => 'admin',
        ]);
        User::create([
            'name' => 'Super Alert', 'email' => 'super-alert@example.test',
            'password' => 'password', 'role' => 'super_admin',
        ]);
        $device = $cafe->devices()->first();
        $device->update([
            'installation_id' => 'installation-alert',
            'activated_at' => now()->subHour(),
            'last_seen_at' => now()->subMinutes(20),
        ]);

        $service = app(OperationalAlertService::class);
        $service->scan();
        $service->scan();

        $this->assertDatabaseCount('operational_alerts', 1);
        $this->assertSame(1, $admin->fresh()->notifications()->count());
        $this->assertDatabaseHas('operational_alerts', [
            'fingerprint' => "device_offline:{$device->id}", 'status' => 'active',
        ]);

        $device->update(['last_seen_at' => now()]);
        $service->scan();

        $this->assertSame('resolved', OperationalAlert::first()->status);
    }

    public function test_admin_alert_page_is_isolated_per_cafe(): void
    {
        $firstCafe = $this->createCafe('FIRST');
        $secondCafe = $this->createCafe('SECOND');
        $admin = User::create([
            'cafe_id' => $firstCafe->id, 'name' => 'Admin First', 'email' => 'first@example.test',
            'password' => 'password', 'role' => 'admin',
        ]);
        OperationalAlert::create([
            'fingerprint' => 'first-alert', 'cafe_id' => $firstCafe->id,
            'category' => 'device_offline', 'severity' => 'danger', 'title' => 'Alert Cafe Pertama',
            'message' => 'Hanya milik cafe pertama', 'status' => 'active',
            'first_detected_at' => now(), 'last_detected_at' => now(),
        ]);
        OperationalAlert::create([
            'fingerprint' => 'second-alert', 'cafe_id' => $secondCafe->id,
            'category' => 'device_offline', 'severity' => 'danger', 'title' => 'Alert Cafe Kedua',
            'message' => 'Tidak boleh terlihat', 'status' => 'active',
            'first_detected_at' => now(), 'last_detected_at' => now(),
        ]);

        $this->actingAs($admin)
            ->get(route('filament.admin.resources.operational-alerts.index'))
            ->assertOk()
            ->assertSee('Alert Cafe Pertama')
            ->assertDontSee('Alert Cafe Kedua');
    }

    private function createCafe(string $code): Cafe
    {
        return Cafe::create([
            'name' => 'Cafe '.$code, 'slug' => strtolower($code), 'code' => $code,
            'status' => 'active', 'device_limit' => 2,
        ]);
    }
}
