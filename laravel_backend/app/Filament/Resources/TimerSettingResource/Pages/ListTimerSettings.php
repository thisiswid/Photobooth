<?php

namespace App\Filament\Resources\TimerSettingResource\Pages;

use App\Filament\Resources\TimerSettingResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListTimerSettings extends ListRecords
{
    protected static string $resource = TimerSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tambah Pengaturan Timer'),
        ];
    }
}
