<?php

namespace App\Filament\SuperAdmin\Resources\PakasirSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\PakasirSettingResource;
use Filament\Resources\Pages\EditRecord;

class EditPakasirSetting extends EditRecord
{
    protected static string $resource = PakasirSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
