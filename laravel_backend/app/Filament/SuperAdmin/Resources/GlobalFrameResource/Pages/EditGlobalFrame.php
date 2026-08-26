<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use App\Services\FrameSlotDetector;
use Filament\Actions\DeleteAction;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

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
        $layoutType = $data['layout_type'] ?? 'single';
        $rightKey = $data['right_column_order'] ?? 'scrambled_1';
        $poseCount = (int)($data['pose_count'] ?? ($layoutType === 'double_8' ? 4 : ($layoutType === 'double_6' ? 3 : 4)));

        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'scrambled_3' => ($layoutType === 'double_8') ? [1, 2, 3, 0] : [2, 0, 1],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
        };

        $slotCount = match($layoutType) {
            'double_6' => 6,
            'double_8' => 8,
            default    => $poseCount,
        };

        $detectedSlots = [];
        $w = 1200;
        $h = 1800;

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

        $finalSlots = FrameSlotDetector::assignSlotPoses($detectedSlots, $layoutType, $rightOrder, $poseCount);

        if (empty($finalSlots)) {
            throw ValidationException::withMessages([
                'asset_url' => 'Frame belum memiliki lubang transparan untuk foto! Silakan gunakan Alat Pensil pada kanvas di bawah untuk mengklik kotak warna foto atau gunakan tombol "Lubangi Hijau Otomatis".',
            ]);
        }

        // Auto-align layout_type if detected slot structure is clearly different from user choice
        $actualSlotCount = count($finalSlots);
        if ($actualSlotCount === 6 && $layoutType === 'single') {
            $layoutType = 'double_6';
            $poseCount = 3;
        } elseif ($actualSlotCount === 8 && $layoutType === 'single') {
            $layoutType = 'double_8';
            $poseCount = 4;
        } elseif ($actualSlotCount <= 4 && in_array($layoutType, ['double_6', 'double_8'])) {
            $layoutType = 'single';
            $poseCount = $actualSlotCount;
        }

        // Re-evaluate rightOrder with the resolved layoutType and apply to slots
        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'scrambled_3' => ($layoutType === 'double_8') ? [1, 2, 3, 0] : [2, 0, 1],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
        };
        $finalSlots = FrameSlotDetector::assignSlotPoses($detectedSlots, $layoutType, $rightOrder, $poseCount);

        $data['layout_type'] = $layoutType;
        $data['pose_count']  = $poseCount;

        $data['layout_config'] = [
            'layout_type'            => $layoutType,
            'slot_count'             => $actualSlotCount,
            'pose_count'             => $poseCount,
            'right_column_order_key' => $rightKey,
            'right_column_order'     => $rightOrder,
            'slots'                  => $finalSlots,
            'dimensions'             => ['w' => $w, 'h' => $h],
        ];

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getSavedNotification(): ?Notification
    {
        return Notification::make()
            ->success()
            ->title('Frame Cafe Berhasil Diperbarui')
            ->body('Perubahan frame cafe telah disimpan.');
    }
}
