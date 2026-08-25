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

        // Auto-assign event_id if empty and user belongs to a cafe
        if (empty($data['event_id']) && ($cafeId = auth()->user()?->cafe_id)) {
            $event = \App\Models\Event::where('cafe_id', $cafeId)->where('active', true)->first()
                ?? \App\Models\Event::where('cafe_id', $cafeId)->latest()->first();
            if ($event) {
                $data['event_id'] = $event->id;
            }
        }

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

            $mode = $data['transparency_mode'] ?? 'auto_alpha';
            $customColor = $data['custom_remove_color'] ?? null;

            if ($mode === 'chroma_green' || $mode === 'custom_color' || !empty($data['remove_green_screen'])) {
                $targetColor = ($mode === 'custom_color') ? $customColor : null;
                $chromaRes = FrameSlotDetector::removeGreenScreenAndDetectSlots($pngPath, $targetColor);
                if (!empty($chromaRes['success'])) {
                    if (!empty($chromaRes['relative_path'])) {
                        $data['asset_url'] = $chromaRes['relative_path'];
                    }
                    if (!empty($chromaRes['slots'])) {
                        $detectedSlots = $chromaRes['slots'];
                        if (!empty($chromaRes['layout_type'])) {
                            $layoutType = $chromaRes['layout_type'];
                        }
                    }
                }
            } elseif ($useAi) {
                $analysis = FrameSlotDetector::analyze($pngPath, autoPunchTransparency: true);
                if (!empty($analysis['punched']) && !empty($analysis['relative_path'])) {
                    $data['asset_url'] = $analysis['relative_path'];
                }
               
                 if (!empty($analysis['slots'])) {
                    $detectedSlots = $analysis['slots'];
                    if (!empty($analysis['layout_type'])) {
                        $layoutType = $analysis['layout_type'];
                    }
                }
            } else {
                // Mode 1: File Sudah Transparan Sendiri (Alpha Channel)
                $isPng = ($imageInfo[2] ?? 0) === IMAGETYPE_PNG;
                if ($isPng) {
                    $alphaRes = FrameSlotDetector::detectAlphaCutouts($pngPath, $w, $h);
                    if (!empty($alphaRes['success']) && !empty($alphaRes['slots'])) {
                        $detectedSlots = $alphaRes['slots'];
                        if (!empty($alphaRes['layout_type'])) {
                            $layoutType = $alphaRes['layout_type'];
                        }
                    }
                }
            }
            
            if (empty($detectedSlots)) {
                $detectedSlots = FrameSlotDetector::generateStandardSlots($w, $h, $layoutType, $poseCount, $rightOrder);
            }
        }

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
