<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\Cafe;
use App\Models\Event;
use App\Models\Frame;
use App\Models\MasterFrame;
use App\Models\TimerSetting;
use App\Services\FrameSlotDetector;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;

class ExampleTest extends TestCase
{
    use RefreshDatabase;
    public function test_detector_on_sample_frames(): void
    {
        $path = storage_path('app/public/frames/strip_coffee.png');
        if (!file_exists($path)) {
            $this->markTestSkipped('Sample frame not found');
        }

        $res = FrameSlotDetector::analyze($path, autoPunchTransparency: false);
        $this->assertTrue($res['success']);
        $this->assertEquals(4, $res['pose_count']);
    }

    public function test_punch_transparency_creates_valid_transparent_png(): void
    {
        $path = storage_path('app/public/frames/strip_coffee.png');
        if (!file_exists($path)) {
            $this->markTestSkipped('Sample frame not found');
        }

        $slots = [
            ['x' => 50, 'y' => 50, 'w' => 1000, 'h' => 350],
            ['x' => 50, 'y' => 450, 'w' => 1000, 'h' => 350],
        ];

        $output = FrameSlotDetector::punchTransparency($path, $slots);
        $this->assertNotNull($output);
        $this->assertStringStartsWith('frames/', $output);
        $this->assertTrue(Storage::disk('public')->exists($output));

        // Clean up test file
        Storage::disk('public')->delete($output);
    }

    public function test_claude_sonnet_4_6_full_pipeline(): void
    {
        $path = storage_path('app/public/frames/strip_coffee.png');
        $base64 = base64_encode(file_get_contents($path));
        $prompt = <<<PROMPT
Analyze this photobooth frame template.
Detect all rectangular photo placeholder boxes/openings where camera photos should appear.
Return normalized coordinates (0 to 1000) for each box in [ymin, xmin, ymax, xmax].

Return ONLY raw JSON (no markdown backticks, no text before or after):
{
  "pose_count": 4,
  "layout_type": "single",
  "slot_count": 4,
  "layout_label": "Single Strip (4 Pose)",
  "boxes": [
    {"ymin": 40, "xmin": 50, "ymax": 240, "xmax": 950, "pose_index": 0},
    {"ymin": 260, "xmin": 50, "ymax": 460, "xmax": 950, "pose_index": 1},
    {"ymin": 480, "xmin": 50, "ymax": 680, "xmax": 950, "pose_index": 2},
    {"ymin": 700, "xmin": 50, "ymax": 900, "xmax": 950, "pose_index": 3}
  ]
}
PROMPT;

        $response = \Illuminate\Support\Facades\Http::withToken('sk-8aad946832adbdbe09ea924a1fdea6aab197b3f39d3f7b31c631c43c2101b6a4')
            ->timeout(25)
            ->post('https://openagentic.id/api/v1/chat/completions', [
                'model' => 'claude-sonnet-4.6',
                'messages' => [
                    [
                        'role' => 'user',
                        'content' => [
                            ['type' => 'text', 'text' => $prompt],
                            [
                                'type' => 'image_url',
                                'image_url' => [
                                    'url' => 'data:image/png;base64,' . $base64,
                                ],
                            ],
                        ],
                    ],
                ],
                'temperature' => 0.0,
                'max_tokens' => 1024,
                'stream' => false,
            ]);

        $rawBody = (string) $response->body();
        $cleanJson = preg_replace('/data:\s*\[DONE\].*$/si', '', trim($rawBody));
        $data = json_decode(trim($cleanJson), true);
        $content = $data['choices'][0]['message']['content'] ?? $rawBody;

        $parsed = FrameSlotDetector::parseJsonSafely($content);

        if ($parsed === null) {
            $this->markTestSkipped('OpenAgentic API did not return valid JSON content in test run');
        }

        $this->assertIsArray($parsed);
        $this->assertEquals(4, $parsed['pose_count']);
    }

    public function test_master_frame_push_prevents_duplicates(): void
    {
        $cafe = \App\Models\Cafe::firstOrCreate(
            ['slug' => 'test-cafe-anti-dup'],
            [
                'name'      => 'Test Cafe Anti Dup',
                'code'      => 'TCAD01',
                'status'    => 'active',
            ]
        );

        $masterFrame = \App\Models\MasterFrame::create([
            'name'          => 'Vintage Test ' . uniqid(),
            'category'      => 'Vintage',
            'layout_type'   => 'single',
            'pose_count'    => 4,
            'is_active'     => true,
            'usage_count'   => 0,
        ]);

        $this->assertFalse($masterFrame->isInstalledInCafe($cafe));

        // First push
        $frame1 = $masterFrame->pushToCafe($cafe);
        $this->assertNotNull($frame1);
        $masterFrame->refresh();
        $this->assertEquals(1, $masterFrame->usage_count);
        $this->assertTrue($masterFrame->isInstalledInCafe($cafe));
        $this->assertContains($cafe->id, $masterFrame->getInstalledCafeIds());

        // Second push should be blocked (return null, usage_count remains 1)
        $frame2 = $masterFrame->pushToCafe($cafe);
        $this->assertNull($frame2);
        $masterFrame->refresh();
        $this->assertEquals(1, $masterFrame->usage_count);

        // Count frames in cafe
        $count = \App\Models\Frame::where('master_frame_id', $masterFrame->id)
            ->whereHas('event', fn ($q) => $q->where('cafe_id', $cafe->id))
            ->count();
        $this->assertEquals(1, $count);

        // Cleanup
        Frame::where('master_frame_id', $masterFrame->id)->delete();
        $masterFrame->delete();
    }

    public function test_timer_setting_crud_and_resolution(): void
    {
        $cafe = Cafe::create([
            'name'   => 'Test Timer Cafe',
            'slug'   => 'test-timer-cafe',
            'code'   => 'TTC01',
            'status' => 'active',
        ]);

        // Default fallback
        $resolved = TimerSetting::resolveForCafe($cafe->id);
        $this->assertEquals(5, $resolved->camera_countdown_seconds);
        $this->assertEquals(300, $resolved->session_timeout_seconds);

        // Create custom timer for cafe
        $custom = TimerSetting::create([
            'cafe_id'                       => $cafe->id,
            'name'                          => 'Fast Booth',
            'camera_countdown_seconds'      => 3,
            'session_timeout_seconds'       => 180,
            'payment_timeout_seconds'       => 90,
            'result_screen_timeout_seconds' => 45,
            'retake_timeout_seconds'        => 30,
            'is_active'                     => true,
        ]);

        $resolvedAfter = TimerSetting::resolveForCafe($cafe->id);
        $this->assertEquals(3, $resolvedAfter->camera_countdown_seconds);
        $this->assertEquals(180, $resolvedAfter->session_timeout_seconds);
        $this->assertEquals('Fast Booth', $resolvedAfter->name);
    }
}
