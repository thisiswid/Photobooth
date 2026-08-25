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
        // ── Declarative Frame Builder inputs ────────────────────────────────
        $slotCount = max(1, min(8, (int) ($data['slot_count'] ?? 4)));
        $columns   = max(1, min(3, (int) ($data['columns'] ?? 1)));
        $aspect    = in_array($data['slot_aspect'] ?? null, ['square', 'landscape'])
            ? $data['slot_aspect']
            : 'portrait';
        $rightKey  = $data['right_column_order'] ?? 'identical';

        $isAiAllowed = \App\Models\AiSetting::isAiAvailable();
        $useAi = $isAiAllowed && !empty($data['use_ai_detection']);

        // ── Resolve canvas dimensions from uploaded asset ───────────────────
        $w = $columns >= 2 ? 1200 : 600;
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

        $layoutConfig = null;

        if ($useAi && $pngPath) {
            // ── Mode AI: deteksi otomatis + punch transparan (fitur lama) ───
            $analysis = FrameSlotDetector::analyze($pngPath, autoPunchTransparency: true);
            if (!empty($analysis['punched']) && !empty($analysis['relative_path'])) {
                $data['asset_url'] = $analysis['relative_path'];
            }

            if (!empty($analysis['slots'])) {
                $layoutConfig = [
                    'layout_type'            => $analysis['layout_type'] ?? 'single',
                    'slot_count'             => count($analysis['slots']),
                    'pose_count'             => $analysis['pose_count'] ?? $slotCount,
                    'columns'                => $columns,
                    'slot_aspect'            => $aspect,
                    'right_column_order_key' => $rightKey,
                    'right_column_order'     => $analysis['right_column_order'] ?? null,
                    'slots'                  => $analysis['slots'],
                    'dimensions'             => ['w' => $w, 'h' => $h],
                ];
            }
        }

        if (!$layoutConfig && $pngPath) {
            // ── Mode Manual ─────────────────────────────────────────────────
            $isPng = ($imageInfo[2] ?? 0) === IMAGETYPE_PNG;
            $alphaSlots = [];

            // 1. PNG sudah transparan → baca lubangnya langsung (lubang = sumber kebenaran)
            if ($isPng) {
                $alphaRes = FrameSlotDetector::detectAlphaCutouts($pngPath, $w, $h);
                if (!empty($alphaRes['success']) && !empty($alphaRes['slots'])) {
                    $alphaSlots = $alphaRes['slots'];
                    $detectedType = $alphaRes['layout_type'] ?? 'single';
                    $columns = in_array($detectedType, ['double_6', 'double_8']) ? 2 : 1;
                }
            }

            if (!empty($alphaSlots)) {
                $poseCount = FrameSlotDetector::computeGridPoseCount(count($alphaSlots), $columns);
                $rightOrder = $columns >= 2 ? FrameSlotDetector::buildRightOrder($rightKey, $poseCount) : null;
                $finalSlots = FrameSlotDetector::assignSlotPoses($alphaSlots, $columns >= 2 ? 'grid' : 'single', $rightOrder, $poseCount, $columns);

                $layoutConfig = [
                    'layout_type'            => $columns >= 2 ? 'grid' : 'single',
                    'slot_count'             => count($finalSlots),
                    'pose_count'             => $poseCount,
                    'columns'                => $columns,
                    'slot_aspect'            => $aspect,
                    'right_column_order_key' => $rightKey,
                    'right_column_order'     => $rightOrder,
                    'slots'                  => $finalSlots,
                    'dimensions'             => ['w' => $w, 'h' => $h],
                ];
            } else {
                // 2. PNG belum transparan → generate grid + lubangi otomatis (GD, tanpa AI)
                $layoutConfig = FrameSlotDetector::buildGridLayoutConfig($w, $h, $slotCount, $columns, $aspect, $rightKey);

                if (!empty($layoutConfig['slots'])) {
                    $punched = FrameSlotDetector::punchTransparency($pngPath, $layoutConfig['slots'], $pngPath);
                    if ($punched) {
                        $data['asset_url'] = $punched;
                    }
                }
            }
        }

        // Fallback tanpa file: tetap generate layout standar
        if (!$layoutConfig) {
            $layoutConfig = FrameSlotDetector::buildGridLayoutConfig($w, $h, $slotCount, $columns, $aspect, $rightKey);
        }

        $data['pose_count']    = $layoutConfig['pose_count'] ?? $slotCount;
        $data['layout_type']   = $layoutConfig['layout_type'] ?? 'single';
        $data['layout_config'] = $layoutConfig;

        // Drop form-only keys (not DB columns; kept out of mass-assignment)
        unset($data['slot_count'], $data['columns'], $data['slot_aspect'], $data['right_column_order'], $data['use_ai_detection']);

        return $data;
    }

    protected function afterSave(): void
    {
        $this->record->syncToCafes();
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
