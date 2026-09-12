<?php

namespace App\Filament\SuperAdmin\Resources\PakasirSettingResource\Pages;

use App\Filament\SuperAdmin\Resources\PakasirSettingResource;
use App\Models\PakasirSetting;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListPakasirSettings extends ListRecords
{
    protected static string $resource = PakasirSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [CreateAction::make()->visible(fn () => !PakasirSetting::query()->exists())];
    }
}
