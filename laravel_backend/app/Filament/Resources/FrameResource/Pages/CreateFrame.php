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

        // Auto-detect transparent slots if asset is uploaded
        $detectedSlots = [];
        if (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $detectedSlots = FrameSlotDetector::detect($pngPath, $layoutType, $rightOrder);
        }

        $data['layout_config'] = [
            'layout_type'            => $layoutType,
            'slot_count'              => count($detectedSlots) ?: $slotCount,
            'right_column_order_key' => $rightKey,
            'right_column_order'     => $rightOrder,
            'slots'                  => $detectedSlots,
        ];

        return $data;
    }
}
