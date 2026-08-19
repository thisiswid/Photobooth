<?php

namespace App\Filament\Resources\DeviceResource\Pages;

use App\Filament\Resources\DeviceResource;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Str;

class CreateDevice extends CreateRecord
{
    protected static string $resource = DeviceResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        if ($cafeId = auth()->user()?->cafe_id) {
            $data['cafe_id'] = $cafeId;
        }

        if (empty($data['device_key'])) {
            $data['device_key'] = Str::random(24);
        }

        return $data;
    }
}
