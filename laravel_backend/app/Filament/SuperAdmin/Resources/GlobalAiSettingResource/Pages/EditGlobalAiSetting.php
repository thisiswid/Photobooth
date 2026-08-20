<?php

namespace App\Filament\SuperAdmin\Resources\GlobalAiSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\GlobalAiSettingResource;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;

class EditGlobalAiSetting extends EditRecord
{
    protected static string $resource = GlobalAiSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    protected function getSavedNotification(): ?Notification
    {
        return Notification::make()
            ->success()
            ->title('Pengaturan AI Diperbarui')
            ->body('Konfigurasi kecerdasan buatan platform berhasil disimpan dan diterapkan.');
    }
}
