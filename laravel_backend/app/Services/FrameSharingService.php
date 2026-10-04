<?php

namespace App\Services;

use App\Models\Event;
use App\Models\Frame;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

class FrameSharingService
{
    /**
     * Create an independent copy for the destination event. Returns null when
     * this source frame has already been shared to that event.
     */
    public static function copyToEvent(Frame $source, Event $destination): ?Frame
    {
        $sourceCafe = $source->event?->cafe;
        if (! $sourceCafe || ! $destination->cafe_id || $sourceCafe->id === $destination->cafe_id) {
            throw new RuntimeException('Frame hanya bisa dibagikan ke event aktif milik cafe lain.');
        }

        if (! $destination->active) {
            throw new RuntimeException('Pilih event tujuan yang aktif agar frame muncul di aplikasi cafe.');
        }

        $sourcePath = (string) $source->asset_url;
        $extension = strtolower(pathinfo($sourcePath, PATHINFO_EXTENSION));
        $disk = Storage::disk('public');

        if (
            ! str_starts_with($sourcePath, 'frames/')
            || str_contains($sourcePath, '..')
            || ! in_array($extension, ['png', 'jpg', 'jpeg', 'webp'], true)
            || ! $disk->exists($sourcePath)
        ) {
            throw new RuntimeException("File gambar frame '{$source->name}' tidak ditemukan di penyimpanan. Bagikan ulang setelah file diperbaiki.");
        }

        return DB::transaction(function () use ($source, $destination, $sourceCafe, $sourcePath, $extension, $disk): ?Frame {
            $destination = Event::query()->lockForUpdate()->findOrFail($destination->id);

            if (Frame::query()
                ->where('event_id', $destination->id)
                ->where('shared_from_frame_id', $source->id)
                ->exists()) {
                return null;
            }

            $copyPath = 'frames/shared/cafe-'.$destination->cafe_id.'/'.Str::uuid().'.'.$extension;
            if (! $disk->copy($sourcePath, $copyPath)) {
                throw new RuntimeException("Gagal menyalin file gambar frame '{$source->name}'.");
            }

            try {
                $suffix = ' (dari '.$sourceCafe->name.')';

                return Frame::create([
                    'event_id' => $destination->id,
                    'shared_from_frame_id' => $source->id,
                    // A shared frame is independent of master template updates.
                    'master_frame_id' => null,
                    'name' => Str::limit($source->name, 255 - mb_strlen($suffix), '').$suffix,
                    'asset_url' => $copyPath,
                    'pose_count' => $source->pose_count,
                    'layout_config' => $source->layout_config,
                    'active' => $source->active,
                ]);
            } catch (\Throwable $exception) {
                $disk->delete($copyPath);

                throw $exception;
            }
        });
    }
}
