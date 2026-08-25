<?php

namespace App\Filament\Resources\FrameResource\Pages;

use App\Filament\Resources\FrameResource;
use App\Services\FrameSlotDetector;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Facades\Storage;

class CreateFrame extends CreateRecord
{
    protected static string $resource = FrameResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        // Auto-assign event_id if empty and user belongs to a cafe
        if (empty($data['event_id']) && ($cafeId = auth()->user()?->cafe_id)) {
            $event = \App\Models\Event::where('cafe_id', $cafeId)->where('active', true)->first()
                ?? \App\Models\Event::where('cafe_id', $cafeId)->latest()->first();
            if ($event) {
                $data['event_id'] = $event->id;
            }
        }

        $w = 600;
        $h = 1800;
        $pngPath = null;
        $imageInfo = null;

        if (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $imageInfo = @getimagesize($pngPath);
            if ($imageInfo) {
                $w = $imageInfo[0];
                $h = $imageInfo[1];
            }
        }

        // Process layout_config from Visual Canvas Editor
        $layoutConfig = $data['layout_config'] ?? [];
        if (is_string($layoutConfig)) {
            $layoutConfig = json_decode($layoutConfig, true) ?: [];
        }

        $slots = $layoutConfig['slots'] ?? [];
        if (empty($slots)) {
            // Default 4 slots fallback
            $slots = FrameSlotDetector::generateStandardSlots($w, $h, 'single', 4);
        }

        // Compute pose_count based on unique/max pose_index assigned to slots
        $maxPoseIndex = 0;
        foreach ($slots as $s) {
            $p = (int) ($s['pose_index'] ?? 0);
            if ($p > $maxPoseIndex) {
                $maxPoseIndex = $p;
            }
        }
        $poseCount = max(1, $maxPoseIndex + 1);

        // Auto-punch transparency on the uploaded image using the slot coordinates
        if ($pngPath && file_exists($pngPath) && !empty($slots)) {
            $punched = FrameSlotDetector::punchTransparency($pngPath, $slots, $pngPath);
            if ($punched) {
                $data['asset_url'] = $punched;
            }
        }

        $data['pose_count'] = $poseCount;
        $data['layout_config'] = [
            'layout_type' => count($slots) <= 4 ? 'single' : 'grid',
            'slot_count'  => count($slots),
            'pose_count'  => $poseCount,
            'slots'       => $slots,
            'dimensions'  => ['w' => $w, 'h' => $h],
        ];

        return $data;
    }
}
