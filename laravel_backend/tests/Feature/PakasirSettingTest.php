<?php

namespace Tests\Feature;

use App\Models\PakasirSetting;
use App\Services\PakasirService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PakasirSettingTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_credentials_override_environment_configuration(): void
    {
        config()->set('services.pakasir.slug', 'env-project');
        config()->set('services.pakasir.api_key', 'env-key');

        $setting = PakasirSetting::create([
            'project_slug' => 'dashboard-project',
            'api_key' => 'dashboard-secret',
            'is_enabled' => true,
        ]);

        $this->assertSame('dashboard-project', PakasirService::credentials()['slug']);
        $this->assertSame('dashboard-secret', PakasirService::credentials()['api_key']);
        $this->assertNotSame('dashboard-secret', $setting->getRawOriginal('api_key'));
    }

    public function test_disabled_database_configuration_disables_gateway(): void
    {
        config()->set('services.pakasir.slug', 'env-project');
        config()->set('services.pakasir.api_key', 'env-key');

        PakasirSetting::create([
            'project_slug' => 'dashboard-project',
            'api_key' => 'dashboard-secret',
            'is_enabled' => false,
        ]);

        $this->assertNull(PakasirService::credentials()['slug']);
        $this->assertNull(PakasirService::credentials()['api_key']);
    }
}
