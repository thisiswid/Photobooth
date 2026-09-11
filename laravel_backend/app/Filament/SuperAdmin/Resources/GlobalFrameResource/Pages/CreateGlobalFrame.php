<?php

namespace App\Filament\SuperAdmin\Resources\GlobalFrameResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalFrameResource;
use App\Services\FrameSlotDetector;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class CreateGlobalFrame extends CreateRecord
{
    protected static string $resource = GlobalFrameResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        return \App\Services\FrameEditorSave::prepare($data, false);
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getCreatedNotification(): ?Notification
    {
        return Notification::make()
            ->success()
            ->title('Frame Cafe Berhasil Dibuat')
            ->body('Frame telah berhasil disimpan untuk cafe yang dipilih.');
    }
}
