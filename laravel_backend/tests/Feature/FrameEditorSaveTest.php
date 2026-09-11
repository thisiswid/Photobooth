<?php

namespace Tests\Feature;

use App\Services\FrameEditorSave;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class FrameEditorSaveTest extends TestCase
{
    private function frame(bool $double = false): array
    {
        Storage::fake('public');
        Storage::disk('public')->makeDirectory('frames');
        $im = imagecreatetruecolor($double ? 1200 : 600, 1800);
        imagefill($im, 0, 0, 0xffffff);
        for ($i = 0; $i < 3; $i++) {
            imagefilledrectangle($im, 60, 80 + $i * 540, 540, 540 + $i * 540, 0xff0000);
            if ($double) imagefilledrectangle($im, 660, 80 + $i * 540, 1140, 540 + $i * 540, 0xff0000);
        }
        imagepng($im, Storage::disk('public')->path('frames/source.png'));
        return ['asset_url' => 'frames/source.png', 'layout_type' => $double ? 'double_6' : 'single',
            'right_column_order' => 'reversed', 'layout_config' => ['color_operations' => [
                ['color' => '#ff0000', 'tolerance' => 15, 'chroma' => false],
            ]]];
    }

    public function test_selected_non_green_color_is_saved_as_transparent_and_source_is_preserved(): void
    {
        $data = FrameEditorSave::prepare($this->frame(), true);
        $image = imagecreatefrompng(Storage::disk('public')->path($data['asset_url']));
        $this->assertSame(127, (imagecolorat($image, 100, 100) >> 24) & 127);
        $this->assertSame(0, (imagecolorat($image, 10, 10) >> 24) & 127);
        $this->assertSame(3, $data['pose_count']);
        $source = imagecreatefrompng(Storage::disk('public')->path('frames/source.png'));
        $this->assertSame(0, (imagecolorat($source, 100, 100) >> 24) & 127);
    }

    public function test_double_six_preserves_three_camera_poses_and_right_order(): void
    {
        $data = FrameEditorSave::prepare($this->frame(true), true);
        $this->assertSame(3, $data['pose_count']);
        $this->assertSame('double_6', $data['layout_config']['layout_type']);
        $this->assertSame([0, 1, 2, 2, 1, 0], array_column($data['layout_config']['slots'], 'pose_index'));
    }

    public function test_opaque_frame_without_edits_is_rejected_instead_of_inventing_slots(): void
    {
        $data = $this->frame();
        $data['layout_config']['color_operations'] = [];
        $this->expectException(ValidationException::class);
        FrameEditorSave::prepare($data, true);
    }
}
