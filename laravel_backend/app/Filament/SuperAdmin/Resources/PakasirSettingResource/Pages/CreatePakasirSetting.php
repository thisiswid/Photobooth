<?php

namespace App\Filament\SuperAdmin\Resources\PakasirSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\PakasirSettingResource;
use App\Models\PakasirSetting;
use Filament\Resources\Pages\CreateRecord;

class CreatePakasirSetting extends CreateRecord
{
    protected static string $resource = PakasirSettingResource::class;

    protected function beforeCreate(): void
    {
        abort_if(PakasirSetting::query()->exists(), 409, 'Konfigurasi Pakasir sudah tersedia.');
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
