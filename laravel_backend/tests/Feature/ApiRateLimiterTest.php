<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiRateLimiterTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_routes_use_a_registered_rate_limiter(): void
    {
        $this->postJson('/api/devices/activate')
            ->assertUnprocessable()
            ->assertJsonPath('success', false);
    }
}
