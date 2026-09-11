<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\CreateRecord;

class CreateUser extends CreateRecord
{
    protected static string $resource = UserResource::class;

    /**
     * Ikat pengguna baru ke cafe pembuatnya.
     *
     * UserResource satu-satunya resource yang tidak punya hook ini, sehingga
     * setiap operator yang dibuat admin cafe lahir dengan cafe_id null dan
     * langsung melihat data seluruh tenant.
     */
    protected function mutateFormDataBeforeCreate(array $data): array
    {
        if ($cafeId = auth()->user()?->cafe_id) {
            $data['cafe_id'] = $cafeId;
        }

        // Role super_admin tidak boleh lahir dari panel per-cafe.
        if (($data['role'] ?? null) === 'super_admin' && !auth()->user()?->isSuperAdmin()) {
            $data['role'] = 'viewer';
        }

        return $data;
    }
}
