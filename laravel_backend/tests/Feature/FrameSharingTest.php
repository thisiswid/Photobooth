<?php

namespace Tests\Feature;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages\ListGlobalFrames;
use App\Models\Cafe;
use App\Models\Event;
use App\Models\Frame;
use App\Models\User;
use App\Services\FrameSharingService;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Livewire\Livewire;
use RuntimeException;
use Tests\TestCase;

class FrameSharingTest extends TestCase
{
    use RefreshDatabase;

    public function test_sharing_copies_the_asset_and_layout_only_to_the_destination_event(): void
    {
        Storage::fake('public');
        $sourceCafe = $this->cafe('asal');
        $destinationCafe = $this->cafe('tujuan');
        $otherCafe = $this->cafe('lain');
        $sourceEvent = $this->event($sourceCafe);
        $destinationEvent = $this->event($destinationCafe);
        $otherEvent = $this->event($otherCafe);
        Storage::disk('public')->put('frames/original.png', 'frame-image');

        $source = Frame::create([
            'event_id' => $sourceEvent->id,
            'name' => 'Frame Senja',
            'asset_url' => 'frames/original.png',
            'pose_count' => 3,
            'layout_config' => ['layout_type' => 'double_6', 'slots' => [['pose_index' => 0]]],
            'active' => true,
        ]);

        $copy = FrameSharingService::copyToEvent($source, $destinationEvent);

        $this->assertNotNull($copy);
        $this->assertSame($destinationEvent->id, $copy->event_id);
        $this->assertSame($source->id, $copy->shared_from_frame_id);
        $this->assertNotSame($source->asset_url, $copy->asset_url);
        $this->assertSame($source->layout_config, $copy->layout_config);
        $this->assertSame(3, $copy->pose_count);
        $this->assertSame('frame-image', Storage::disk('public')->get($copy->asset_url));
        $this->assertNull(FrameSharingService::copyToEvent($source, $destinationEvent));
        $this->assertSame(1, $destinationEvent->frames()->count());
        $this->assertSame(0, $otherEvent->frames()->count());

        Storage::disk('public')->delete($source->asset_url);
        $source->delete();
        $this->assertTrue(Storage::disk('public')->exists($copy->asset_url));
        $this->assertDatabaseHas('frames', ['id' => $copy->id, 'event_id' => $destinationEvent->id]);
    }

    public function test_super_admin_can_share_multiple_selected_frames(): void
    {
        Storage::fake('public');
        $sourceCafe = $this->cafe('bulk-asal');
        $destinationCafe = $this->cafe('bulk-tujuan');
        $sourceEvent = $this->event($sourceCafe);
        $destinationEvent = $this->event($destinationCafe);
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'frame-sharing@example.test',
            'password' => 'password',
            'role' => 'super_admin',
        ]);

        $frames = collect([1, 2])->map(function (int $number) use ($sourceEvent): Frame {
            $path = "frames/bulk-{$number}.png";
            Storage::disk('public')->put($path, "image-{$number}");

            return Frame::create([
                'event_id' => $sourceEvent->id,
                'name' => "Frame {$number}",
                'asset_url' => $path,
                'active' => true,
            ]);
        });

        $previousPanel = Filament::getCurrentPanel();

        try {
            Filament::setCurrentPanel(Filament::getPanel('super_admin'));

            Livewire::actingAs($superAdmin)
                ->test(ListGlobalFrames::class)
                ->callTableAction('shareToCafe', $frames->first(), [
                    'cafe_id' => $destinationCafe->id,
                    'event_id' => $destinationEvent->id,
                ])
                ->assertHasNoTableActionErrors();

            Livewire::actingAs($superAdmin)
                ->test(ListGlobalFrames::class)
                ->callTableBulkAction('shareToCafe', $frames, [
                    'cafe_id' => $destinationCafe->id,
                    'event_id' => $destinationEvent->id,
                ])
                ->assertHasNoTableBulkActionErrors();
        } finally {
            Filament::setCurrentPanel($previousPanel);
        }

        $this->assertSame(2, $destinationEvent->frames()->count());
        $this->assertSame(2, $sourceEvent->frames()->count());
    }

    public function test_sharing_to_same_cafe_or_missing_image_is_rejected(): void
    {
        Storage::fake('public');
        $sourceCafe = $this->cafe('invalid-asal');
        $otherCafe = $this->cafe('invalid-tujuan');
        $sourceEvent = $this->event($sourceCafe);
        $destinationEvent = $this->event($otherCafe);
        $source = Frame::create([
            'event_id' => $sourceEvent->id,
            'name' => 'Tidak Ada File',
            'asset_url' => 'frames/missing.png',
            'active' => true,
        ]);

        try {
            FrameSharingService::copyToEvent($source, $sourceEvent);
            $this->fail('Sharing to the source cafe must be rejected.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('cafe lain', $exception->getMessage());
        }

        $this->expectException(RuntimeException::class);
        FrameSharingService::copyToEvent($source, $destinationEvent);
    }

    private function cafe(string $code): Cafe
    {
        return Cafe::create([
            'name' => 'Cafe '.$code,
            'slug' => $code,
            'code' => strtoupper($code),
            'status' => 'active',
        ]);
    }

    private function event(Cafe $cafe): Event
    {
        return Event::create([
            'cafe_id' => $cafe->id,
            'name' => 'Booth Utama',
            'active' => true,
        ]);
    }
}
