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
        $layoutType = $data['layout_type'] ?? 'single';
        $rightKey = $data['right_column_order'] ?? 'scrambled_1';

        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => [2, 0, 1],
        };

        $slotCount = match($layoutType) {
            'double_6' => 6,
            'double_8' => 8,
            default    => (int)($data['pose_count'] ?? 4),
        };

        // Auto-assign event_id if empty and user belongs to a cafe
        if (empty($data['event_id']) && ($cafeId = auth()->user()?->cafe_id)) {
            $event = \App\Models\Event::where('cafe_id', $cafeId)->where('active', true)->first()
                ?? \App\Models\Event::where('cafe_id', $cafeId)->latest()->first();
            if ($event) {
                $data['event_id'] = $event->id;
            }
        }

        // Auto-detect transparent slots and punch transparency if needed
        $detectedSlots = [];
        if (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $analysis = FrameSlotDetector::analyze($pngPath, autoPunchTransparency: true);
            if (!empty($analysis['punched']) && !empty($analysis['relative_path'])) {
                $data['asset_url'] = $analysis['relative_path'];
            }
            
            // Only use auto-detected slots if their layout type matches user's chosen layoutType
            if (!empty($analysis['slots']) && ($analysis['layout_type'] ?? '') === $layoutType) {
                $detectedSlots = $analysis['slots'];
            } else {
                $imageInfo = @getimagesize($pngPath);
                $w = $imageInfo[0] ?? 1200;
                $h = $imageInfo[1] ?? 1800;
                $detectedSlots = FrameSlotDetector::generateStandardSlots($w, $h, $layoutType, (int)($data['pose_count'] ?? 4));
            }
        }

        $data['layout_config'] = [
            'layout_type'            => $layoutType,
            'slot_count'             => count($detectedSlots) ?: $slotCount,
            'right_column_order_key' => $rightKey,
            'right_column_order'     => $rightOrder,
            'slots'                  => $detectedSlots,
        ];

        return $data;
    }
}
