<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Services\FrameSlotDetector;
use Illuminate\Support\Facades\Storage;

class ExampleTest extends TestCase
{
    public function test_detector_on_sample_frames(): void
    {
        $path = storage_path('app/public/frames/strip_coffee.png');
        if (!file_exists($path)) {
            $this->markTestSkipped('Sample frame not found');
        }

        $res = FrameSlotDetector::analyze($path, autoPunchTransparency: false);
        $this->assertTrue($res['success']);
        $this->assertGreaterThanOrEqual(1, $res['pose_count']);
        $this->assertNotEmpty($res['slots']);
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

        if (!$response->successful()) {
            $this->markTestSkipped('OpenAgentic API not reachable or quota exceeded: ' . $response->status());
        }

        $rawBody = (string) $response->body();
        $cleanJson = preg_replace('/data:\s*\[DONE\].*$/si', '', trim($rawBody));
        $data = json_decode(trim($cleanJson), true);
        $content = $data['choices'][0]['message']['content'] ?? $rawBody;

        $parsed = FrameSlotDetector::parseJsonSafely($content);

        $this->assertIsArray($parsed);
        $this->assertArrayHasKey('pose_count', $parsed);
    }

    public function test_assign_slot_poses_scrambled_layouts(): void
    {
        $rawSlots = [
            ['x' => 50,  'y' => 50,  'w' => 400, 'h' => 300],
            ['x' => 50,  'y' => 400, 'w' => 400, 'h' => 300],
            ['x' => 50,  'y' => 750, 'w' => 400, 'h' => 300],
            ['x' => 500, 'y' => 50,  'w' => 400, 'h' => 300],
            ['x' => 500, 'y' => 400, 'w' => 400, 'h' => 300],
            ['x' => 500, 'y' => 750, 'w' => 400, 'h' => 300],
        ];

        // Scrambled 1: Right column is [2, 0, 1] (Pose 3, Pose 1, Pose 2)
        $slots1 = FrameSlotDetector::assignSlotPoses($rawSlots, 'double_6', [2, 0, 1], 3);
        $this->assertCount(6, $slots1);
        $this->assertEquals(0, $slots1[0]['pose_index']); // Left row 0: Pose 1
        $this->assertEquals(1, $slots1[1]['pose_index']); // Left row 1: Pose 2
        $this->assertEquals(2, $slots1[2]['pose_index']); // Left row 2: Pose 3
        $this->assertEquals(2, $slots1[3]['pose_index']); // Right row 0: Pose 3
        $this->assertEquals(0, $slots1[4]['pose_index']); // Right row 1: Pose 1
        $this->assertEquals(1, $slots1[5]['pose_index']); // Right row 2: Pose 2

        // Scrambled 2: Right column is [1, 2, 0] (Pose 2, Pose 3, Pose 1)
        $slots2 = FrameSlotDetector::assignSlotPoses($rawSlots, 'double_6', [1, 2, 0], 3);
        $this->assertEquals(1, $slots2[3]['pose_index']); // Right row 0: Pose 2
        $this->assertEquals(2, $slots2[4]['pose_index']); // Right row 1: Pose 3
        $this->assertEquals(0, $slots2[5]['pose_index']); // Right row 2: Pose 1
    }
}
