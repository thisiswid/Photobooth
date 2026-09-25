<?php

namespace Tests\Feature;

use App\Models\Cafe;
use App\Models\User;
use App\Support\AdminGuide;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AdminGuideTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $cafe = Cafe::create(['name' => 'Cafe Panduan', 'slug' => 'cafe-panduan', 'code' => 'GUIDE', 'status' => 'active']);

        return User::create(['cafe_id' => $cafe->id, 'name' => 'Admin Panduan', 'email' => 'guide@example.test', 'password' => 'password', 'role' => 'admin']);
    }

    public function test_documentation_requires_login_and_login_has_no_tour(): void
    {
        $this->get('/admin/dokumentasi')->assertRedirect('/admin/login');
        $this->get('/admin/login')->assertOk()->assertDontSee('id="photobooth-help"', false);
    }

    public function test_documentation_contains_admin_and_kiosk_guides_and_screenshot_instructions(): void
    {
        $response = $this->actingAs($this->admin())->get('/admin/dokumentasi');
        $response->assertOk()->assertSee('Panduan admin')->assertSee('Panduan aplikasi kiosk')
            ->assertSee('id="photobooth-help"', false)->assertSee('Tempat screenshot');

        foreach (config('photobooth-guide') as $group => $guides) {
            foreach ($guides as $slug => $guide) {
                $response->assertSee($guide['title'])->assertSee("public/images/documentation/{$group}-{$slug}.png");
            }
        }
    }

    public function test_every_admin_resource_has_a_specific_guide_and_separate_page_modes(): void
    {
        foreach (Route::getRoutes() as $route) {
            $name = $route->getName() ?? '';
            if (! str_starts_with($name, 'filament.admin.resources.')) {
                continue;
            }
            $topic = explode('.', $name)[3];
            $this->assertNotNull(config("photobooth-guide.admin.{$topic}"), "Missing guide: {$name}");
            $tour = AdminGuide::tour($name);
            $this->assertNotEmpty($tour['steps']);
            $this->assertSame(config("photobooth-guide.admin.{$topic}.title"), $tour['steps'][0]['title']);
        }

        $this->assertSame('devices.edit', AdminGuide::tour('filament.admin.resources.devices.edit')['key']);
        $this->assertNotSame(AdminGuide::tour('filament.admin.resources.devices.index')['key'], AdminGuide::tour('filament.admin.resources.devices.create')['key']);
    }

    public function test_help_is_rendered_on_dashboard_list_create_and_edit_pages(): void
    {
        $admin = $this->admin();
        foreach (['/admin', '/admin/devices', '/admin/devices/create', '/admin/cafes/'.$admin->cafe_id.'/edit'] as $url) {
            $this->actingAs($admin)->get($url)->assertOk()
                ->assertSee('id="photobooth-help"', false)
                ->assertSee('admin-guide.js')
                ->assertSee('photobooth-guide-config');
        }
    }
}
