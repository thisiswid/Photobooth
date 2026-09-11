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
        return \App\Services\FrameEditorSave::prepare($data, true);
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getSavedNotification(): ?\Filament\Notifications\Notification
    {
        return \Filament\Notifications\Notification::make()
            ->success()
            ->title('Master Frame Berhasil Diperbarui')
            ->body('Perubahan master frame telah disimpan dan disinkronkan ke cafe.');
    }
}
