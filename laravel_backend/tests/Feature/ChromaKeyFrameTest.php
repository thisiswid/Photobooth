<?php

namespace Tests\Feature;

use App\Services\FrameSlotDetector;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ChromaKeyFrameTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_removes_green_screen_and_detects_single_strip_slots()
    {
        Storage::fake('public');

        // Create a synthetic 600x1800 test frame with 4 bright green rectangles (#00FF00)
        $w = 600;
        $h = 1800;
        $im = imagecreatetruecolor($w, $h);
        $white = imagecolorallocate($im, 255, 255, 255);
        $green = imagecolorallocate($im, 0, 255, 0);

        imagefilledrectangle($im, 0, 0, $w, $h, $white);

        // 4 Green photo slots
        $slotH = 340;
        $gap = 60;
        $top = 60;
        for ($i = 0; $i < 4; $i++) {
            $y1 = $top + $i * ($slotH + $gap);
            $y2 = $y1 + $slotH;
            imagefilledrectangle($im, 40, $y1, $w - 40, $y2, $green);
        }

        $tempFile = tempnam(sys_get_temp_dir(), 'chroma_test') . '.png';
        imagepng($im, $tempFile);
        imagedestroy($im);

        $res = FrameSlotDetector::removeGreenScreenAndDetectSlots($tempFile);

        $this->assertTrue($res['success']);
        $this->assertNotEmpty($res['relative_path']);
        $this->assertCount(4, $res['slots']);
        $this->assertEquals('single', $res['layout_type']);

        // Check transparency of the result
        $savedPath = storage_path('app/public/' . $res['relative_path']);
        $this->assertFileExists($savedPath);

        $outIm = imagecreatefrompng($savedPath);
        // Check pixel in middle of slot 1 is transparent (alpha > 64)
        $rgb = imagecolorat($outIm, 300, 150);
        $alpha = ($rgb & 0x7F000000) >> 24;
        $this->assertGreaterThan(64, $alpha, 'Green area should become transparent');

        // Check corner background is still white opaque (alpha == 0)
        $rgbBg = imagecolorat($outIm, 10, 10);
        $alphaBg = ($rgbBg & 0x7F000000) >> 24;
        $this->assertEquals(0, $alphaBg, 'Background should remain opaque');

        imagedestroy($outIm);
        @unlink($tempFile);
        @unlink($savedPath);
    }

    public function test_it_removes_green_screen_and_detects_double_strip_slots()
    {
        Storage::fake('public');

        // Create a synthetic 1200x1800 double strip with 2 columns of 3 green slots
        $w = 1200;
        $h = 1800;
        $im = imagecreatetruecolor($w, $h);
        $white = imagecolorallocate($im, 255, 255, 255);
        $green = imagecolorallocate($im, 0, 255, 0);

        imagefilledrectangle($im, 0, 0, $w, $h, $white);

        $slotW = 480;
        $slotH = 460;
        $gap = 60;
        $top = 80;

        for ($r = 0; $r < 3; $r++) {
            $y1 = $top + $r * ($slotH + $gap);
            $y2 = $y1 + $slotH;
            // Left column
            imagefilledrectangle($im, 60, $y1, 60 + $slotW, $y2, $green);
            // Right column
            imagefilledrectangle($im, 660, $y1, 660 + $slotW, $y2, $green);
        }

        $tempFile = tempnam(sys_get_temp_dir(), 'chroma_double_test') . '.png';
        imagepng($im, $tempFile);
        imagedestroy($im);

        $res = FrameSlotDetector::removeGreenScreenAndDetectSlots($tempFile);

        $this->assertTrue($res['success']);
        $this->assertNotEmpty($res['relative_path']);
        $this->assertCount(6, $res['slots']);
        $this->assertEquals('double_6', $res['layout_type']);

        $savedPath = storage_path('app/public/' . $res['relative_path']);
        @unlink($tempFile);
        @unlink($savedPath);
    }

    public function test_it_removes_green_screen_and_detects_double_8_strip_slots()
    {
        Storage::fake('public');

        // Create a synthetic 1200x1800 double strip with 2 columns of 4 green slots (8 slots total)
        $w = 1200;
        $h = 1800;
        $im = imagecreatetruecolor($w, $h);
        $white = imagecolorallocate($im, 255, 255, 255);
        $green = imagecolorallocate($im, 0, 255, 0);

        imagefilledrectangle($im, 0, 0, $w, $h, $white);

        $slotW = 480;
        $slotH = 340;
        $gap = 45;
        $top = 60;

        for ($r = 0; $r < 4; $r++) {
            $y1 = $top + $r * ($slotH + $gap);
            $y2 = $y1 + $slotH;
            // Left column
            imagefilledrectangle($im, 60, $y1, 60 + $slotW, $y2, $green);
            // Right column
            imagefilledrectangle($im, 660, $y1, 660 + $slotW, $y2, $green);
        }

        $tempFile = tempnam(sys_get_temp_dir(), 'chroma_double_8_test') . '.png';
        imagepng($im, $tempFile);
        imagedestroy($im);

        $res = FrameSlotDetector::removeGreenScreenAndDetectSlots($tempFile);

        $this->assertTrue($res['success']);
        $this->assertNotEmpty($res['relative_path']);
        $this->assertCount(8, $res['slots']);
        $this->assertEquals('double_8', $res['layout_type']);

        $savedPath = storage_path('app/public/' . $res['relative_path']);
        @unlink($tempFile);
        @unlink($savedPath);
    }

    public function test_it_removes_custom_pipette_color_and_detects_natural_slots()
    {
        Storage::fake('public');

        // Test custom magenta (#FF00FF) placeholder boxes
        $w = 600;
        $h = 1800;
        $im = imagecreatetruecolor($w, $h);
        $black = imagecolorallocate($im, 20, 20, 20);
        $magenta = imagecolorallocate($im, 255, 0, 255);

        imagefilledrectangle($im, 0, 0, $w, $h, $black);

        // 3 Magenta boxes
        $slotH = 450;
        $gap = 70;
        $top = 80;
        for ($i = 0; $i < 3; $i++) {
            $y1 = $top + $i * ($slotH + $gap);
            $y2 = $y1 + $slotH;
            imagefilledrectangle($im, 50, $y1, $w - 50, $y2, $magenta);
        }

        $tempFile = tempnam(sys_get_temp_dir(), 'pipette_test') . '.png';
        imagepng($im, $tempFile);
        imagedestroy($im);

        // Remove magenta with custom hex #FF00FF
        $res = FrameSlotDetector::removeGreenScreenAndDetectSlots($tempFile, '#FF00FF');

        $this->assertTrue($res['success']);
        $this->assertCount(3, $res['slots']);
        $this->assertEquals('single', $res['layout_type']);

        $savedPath = storage_path('app/public/' . $res['relative_path']);
        $this->assertFileExists($savedPath);

        $outIm = imagecreatefrompng($savedPath);
        // Middle of slot 1 should be transparent
        $rgb = imagecolorat($outIm, 300, 200);
        $alpha = ($rgb & 0x7F000000) >> 24;
        $this->assertGreaterThan(64, $alpha, 'Custom magenta area should become transparent');

        // Background should remain black opaque
        $rgbBg = imagecolorat($outIm, 10, 10);
        $alphaBg = ($rgbBg & 0x7F000000) >> 24;
        $this->assertEquals(0, $alphaBg);

        imagedestroy($outIm);
        @unlink($tempFile);
        @unlink($savedPath);
    }
}
