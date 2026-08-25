<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

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
        if (!empty($data['remove_green_screen']) && !empty($data['asset_url'])) {
            $pngPath = \Illuminate\Support\Facades\Storage::disk('public')->path($data['asset_url']);
            $chromaRes = \App\Services\FrameSlotDetector::removeGreenScreenAndDetectSlots($pngPath);
            if (!empty($chromaRes['success'])) {
                if (!empty($chromaRes['relative_path'])) {
                    $data['asset_url'] = $chromaRes['relative_path'];
                }
                if (!empty($chromaRes['slots'])) {
                    $data['layout_config'] = [
                        'layout_type' => $chromaRes['layout_type'] ?? 'single',
                        'slot_count'  => $chromaRes['slot_count'] ?? 4,
                        'slots'       => $chromaRes['slots'],
                        'dimensions'  => $chromaRes['dimensions'] ?? ['w' => 1200, 'h' => 1800],
                    ];
                }
            }
        }
        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
