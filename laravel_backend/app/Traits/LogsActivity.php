<?php

namespace App\Traits;

use App\Models\ActivityLog;

trait LogsActivity
{
    public static function bootLogsActivity(): void
    {
        static::created(function ($model) {
            $name = class_basename($model);
            $ident = $model->name ?? $model->title ?? $model->reference_no ?? $model->device_key ?? "#{$model->getKey()}";
            ActivityLog::record(
                action: 'create',
                description: "Menambahkan data {$name}: {$ident}",
                subject: $model,
                properties: ['attributes' => $model->getAttributes()]
            );
        });

        static::updated(function ($model) {
            $changes = $model->getChanges();
            // Abaikan jika hanya updated_at yang berubah
            unset($changes['updated_at']);
            if (empty($changes)) {
                return;
            }

            $name = class_basename($model);
            $ident = $model->name ?? $model->title ?? $model->reference_no ?? $model->device_key ?? "#{$model->getKey()}";
            $original = array_intersect_key($model->getOriginal(), $changes);

            ActivityLog::record(
                action: 'update',
                description: "Memperbarui data {$name}: {$ident}",
                subject: $model,
                properties: [
                    'old' => $original,
                    'new' => $changes,
                ]
            );
        });

        static::deleted(function ($model) {
            $name = class_basename($model);
            $ident = $model->name ?? $model->title ?? $model->reference_no ?? $model->device_key ?? "#{$model->getKey()}";
            ActivityLog::record(
                action: 'delete',
                description: "Menghapus data {$name}: {$ident}",
                subject: $model,
                properties: ['old' => $model->getAttributes()]
            );
        });
    }
}
