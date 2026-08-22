<?php

namespace App\Filament\Resources\FrameResource\Pages;

use App\Filament\Resources\FrameResource;
use App\Services\FrameSlotDetector;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Storage;

class EditFrame extends EditRecord
{
    protected static string $resource = FrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $layoutType = $data['layout_type'] ?? 'single';
        $rightKey = $data['right_column_order'] ?? 'scrambled_1';
        $poseCount = (int)($data['pose_count'] ?? ($layoutType === 'double_8' ? 4 : ($layoutType === 'double_6' ? 3 : 4)));
        $isAiAllowed = \App\Models\AiSetting::isAiAvailable(auth()->user()?->cafe_id);
        $useAi = $isAiAllowed && (!isset($data['use_ai_detection']) || (bool)$data['use_ai_detection']);

        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
        };

        $slotCount = match($layoutType) {
            'double_6' => 6,
            'double_8' => 8,
            default    => $poseCount,
        };

        // Slot processing & dimensions
        $detectedSlots = [];
        $w = 1200;
        $h = 1800;

        if (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $imageInfo = @getimagesize($pngPath);
            if ($imageInfo) {
                $w = $imageInfo[0];
                $h = $imageInfo[1];
            }

            // Smart Fail-Safe: Cek rasio kanvas gambar
            // Jika rasio <= 0.45 (misal 600x1800 -> 0.333), ini pasti Single Strip vertikal
            $aspectRatio = $h > 0 ? ($w / $h) : 0.66;
            if ($aspectRatio <= 0.45 && in_array($layoutType, ['double_6', 'double_8'])) {
                $layoutType = 'single';
                $poseCount = 4;
                $slotCount = 4;
            }

            if ($useAi) {
                $analysis = FrameSlotDetector::analyze($pngPath, autoPunchTransparency: true);
                if (!empty($analysis['punched']) && !empty($analysis['relative_path'])) {
                    $data['asset_url'] = $analysis['relative_path'];
                }
                
                if (!empty($analysis['slots'])) {
                    $detectedSlots = $analysis['slots'];
                }
            } else {
                // Mode Manual: Cek apakah file PNG sudah memiliki lubang transparan (Alpha Channel)
                $isPng = ($imageInfo[2] ?? 0) === IMAGETYPE_PNG;
                if ($isPng) {
                    $alphaRes = FrameSlotDetector::detectAlphaCutouts($pngPath, $w, $h);
                    if (!empty($alphaRes['success']) && !empty($alphaRes['slots'])) {
                        $detectedSlots = $alphaRes['slots'];
                    }
                }
            }
            
            if (empty($detectedSlots)) {
                $detectedSlots = FrameSlotDetector::generateStandardSlots($w, $h, $layoutType, $poseCount, $rightOrder);
            }
        }

        // Smart Fail-Safe: Enforce strict pose_count & slot_count according to layout
        if ($layoutType === 'double_6') {
            $poseCount = 3;
            $slotCount = 6;
        } elseif ($layoutType === 'double_8') {
            $poseCount = 4;
            $slotCount = 8;
        } else {
            $slotCount = $poseCount;
        }

        $data['pose_count'] = $poseCount;
        $data['layout_type'] = $layoutType;

        // Ensure pose_index in slots accurately aligns with chosen rightOrder
        $finalSlots = FrameSlotDetector::assignSlotPoses($detectedSlots, $layoutType, $rightOrder, $poseCount);

        $data['layout_config'] = [
            'layout_type'            => $layoutType,
            'slot_count'             => count($finalSlots) ?: $slotCount,
            'right_column_order_key' => $rightKey,
            'right_column_order'     => $rightOrder,
            'slots'                  => $finalSlots,
            'dimensions'             => ['w' => $w, 'h' => $h],
        ];

        return $data;
    }
}
