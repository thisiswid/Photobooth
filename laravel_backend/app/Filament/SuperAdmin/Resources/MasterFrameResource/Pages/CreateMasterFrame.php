<?php

namespace App\Filament\SuperAdmin\Resources\MasterFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\MasterFrameResource;
use App\Services\FrameSlotDetector;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Facades\Storage;

class CreateMasterFrame extends CreateRecord
{
    protected static string $resource = MasterFrameResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        return \App\Services\FrameEditorSave::prepare($data, true);
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getCreatedNotification(): ?\Filament\Notifications\Notification
    {
        return \Filament\Notifications\Notification::make()
            ->success()
            ->title('Master Frame Berhasil Dibuat')
            ->body('Template master frame telah disimpan dan tersedia untuk cafe.');
    }
}
