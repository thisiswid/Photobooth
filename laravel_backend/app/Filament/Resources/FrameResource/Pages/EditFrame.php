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

        // Check if user clicked and punched slots on the interactive canvas
        $clientSlots = $data['layout_config']['slots'] ?? [];
        if (!empty($clientSlots) && is_array($clientSlots)) {
            $detectedSlots = $clientSlots;
            $poseCount = max(1, count($detectedSlots));
            $layoutType = count($detectedSlots) <= 4 ? 'single' : 'grid';

            if (!empty($data['asset_url'])) {
                $pngPath = Storage::disk('public')->path($data['asset_url']);
                $imageInfo = @getimagesize($pngPath);
                if ($imageInfo) {
                    $w = $imageInfo[0];
                    $h = $imageInfo[1];
                }
                // If the user used green removal on canvas, run pixel-level chroma keying without destroying stickers/assets
                $chromaRes = FrameSlotDetector::removeGreenScreenAndDetectSlots($pngPath);
                if (!empty($chromaRes['success']) && !empty($chromaRes['relative_path'])) {
                    $data['asset_url'] = $chromaRes['relative_path'];
                }
            }
        } elseif (!empty($data['asset_url'])) {
            $pngPath = Storage::disk('public')->path($data['asset_url']);
            $imageInfo = @getimagesize($pngPath);
            if ($imageInfo) {
                $w = $imageInfo[0];
                $h = $imageInfo[1];
            }

            // Check if file is transparent PNG or has chroma green
            $chromaRes = FrameSlotDetector::removeGreenScreenAndDetectSlots($pngPath);
            if (!empty($chromaRes['success']) && !empty($chromaRes['slots'])) {
                if (!empty($chromaRes['relative_path'])) {
                    $data['asset_url'] = $chromaRes['relative_path'];
                }
                $detectedSlots = $chromaRes['slots'];
                if (!empty($chromaRes['layout_type'])) {
                    $layoutType = $chromaRes['layout_type'];
                }
            } else {
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
