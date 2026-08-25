<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use App\Services\FrameSlotDetector;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Storage;

class EditGlobalFrame extends EditRecord
{
    protected static string $resource = GlobalFrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
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

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
