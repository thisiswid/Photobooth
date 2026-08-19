<?php

namespace App\Filament\SuperAdmin\Resources\MasterFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\MasterFrameResource;
use App\Services\FrameSlotDetector;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Storage;

class EditMasterFrame extends EditRecord
{
    protected static string $resource = MasterFrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $layoutType = $data['layout_type'] ?? 'single';
        $slotCount = match($layoutType) {
            'double_6' => 6,
            'double_8' => 8,
            default    => (int)($data['pose_count'] ?? 4),
        };

        $detectedSlots = [];
        if (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $analysis = FrameSlotDetector::analyze($pngPath, autoPunchTransparency: true);
            if (!empty($analysis['punched']) && !empty($analysis['relative_path'])) {
                $data['asset_url'] = $analysis['relative_path'];
            }
            $detectedSlots = $analysis['slots'] ?? [];
        }

        $data['layout_config'] = [
            'layout_type' => $layoutType,
            'slot_count'  => count($detectedSlots) ?: $slotCount,
            'slots'       => $detectedSlots,
        ];

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
