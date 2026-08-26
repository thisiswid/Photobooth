<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MasterFrame extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'category',
        'layout_type',
        'pose_count',
        'asset_url',
        'layout_config',
        'description',
        'is_active',
        'usage_count',
    ];

    protected $casts = [
        'is_active'     => 'boolean',
        'pose_count'    => 'integer',
        'layout_config' => 'array',
        'usage_count'   => 'integer',
    ];

    public function frames(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Frame::class, 'master_frame_id');
    }

    /**
     * Get list of Cafe IDs that already have this MasterFrame installed.
     */
    public function getInstalledCafeIds(): array
    {
        return Cafe::whereHas('events.frames', function ($q) {
            $q->where('master_frame_id', $this->id)
              ->orWhere('name', $this->name);
        })->pluck('id')->toArray();
    }

    /**
     * Check whether a specific cafe already has this MasterFrame.
     */
    public function isInstalledInCafe(int|Cafe $cafe): bool
    {
        $cafeId = $cafe instanceof Cafe ? $cafe->id : $cafe;
        return Frame::whereHas('event', fn ($q) => $q->where('cafe_id', $cafeId))
            ->where(function ($q) {
                $q->where('master_frame_id', $this->id)
                  ->orWhere('name', $this->name);
            })
            ->exists();
    }

    /**
     * Copy / Push this MasterFrame into a specific Cafe's active Event.
     * Prevents duplication: returns null if already installed unless $forceUpdate is true.
     */
    public function pushToCafe(Cafe $cafe, bool $forceUpdate = false): ?Frame
    {
        // Cari event aktif cafe atau buat event default
        $event = Event::firstOrCreate(
            ['cafe_id' => $cafe->id, 'active' => true],
            [
                'name'        => 'Main Booth Event - ' . $cafe->name,
                'description' => 'Event photobooth utama untuk ' . $cafe->name,
                'starts_at'   => now(),
                'active'      => true,
            ]
        );

        // Cek apakah cafe sudah memiliki frame ini di event manapun milik cafe
        $existingFrame = Frame::whereHas('event', fn ($q) => $q->where('cafe_id', $cafe->id))
            ->where(function ($q) {
                $q->where('master_frame_id', $this->id)
                  ->orWhere('name', $this->name);
            })
            ->first();

        if ($existingFrame && !$forceUpdate) {
            // Pastikan master_frame_id terhubung jika sebelumnya null
            if (!$existingFrame->master_frame_id) {
                $existingFrame->update(['master_frame_id' => $this->id]);
            }
            return null; // Menandakan frame sudah ada (tidak diduplikasi)
        }

        $layoutConfig = $this->layout_config ?? [];
        $layoutType = $this->layout_type ?? ($layoutConfig['layout_type'] ?? 'single');
        $layoutConfig['layout_type'] = $layoutType;

        $rightKey = $layoutConfig['right_column_order_key'] ?? 'scrambled_1';
        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'scrambled_3' => ($layoutType === 'double_8') ? [1, 2, 3, 0] : [2, 0, 1],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
        };

        $layoutConfig['right_column_order_key'] = $rightKey;
        $layoutConfig['right_column_order'] = $rightOrder;

        if (!empty($layoutConfig['slots'])) {
            $layoutConfig['slots'] = \App\Services\FrameSlotDetector::assignSlotPoses(
                $layoutConfig['slots'],
                $layoutType,
                $rightOrder,
                $this->pose_count ?? 4
            );
        }

        if ($existingFrame) {
            $existingFrame->update([
                'master_frame_id' => $this->id,
                'name'            => $this->name,
                'asset_url'       => $this->asset_url,
                'pose_count'      => $this->pose_count,
                'layout_config'   => $layoutConfig,
                'active'          => $this->is_active,
            ]);
            return $existingFrame;
        }

        $frame = Frame::create([
            'event_id'        => $event->id,
            'master_frame_id' => $this->id,
            'name'            => $this->name,
            'asset_url'       => $this->asset_url,
            'pose_count'      => $this->pose_count,
            'layout_config'   => $layoutConfig,
            'active'          => $this->is_active,
        ]);

        $this->increment('usage_count');

        return $frame;
    }

    /**
     * Synchronize updates made in MasterFrame to all distributed Cafe frames.
     */
    public function syncToCafes(): void
    {
        $layoutConfig = $this->layout_config ?? [];
        $layoutType = $this->layout_type ?? ($layoutConfig['layout_type'] ?? 'single');
        $layoutConfig['layout_type'] = $layoutType;

        $rightKey = $layoutConfig['right_column_order_key'] ?? 'scrambled_1';
        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
            'scrambled_3' => ($layoutType === 'double_8') ? [1, 2, 3, 0] : [2, 0, 1],
            'reversed'    => ($layoutType === 'double_8') ? [3, 2, 1, 0] : [2, 1, 0],
            'identical'   => ($layoutType === 'double_8') ? [0, 1, 2, 3] : [0, 1, 2],
            default       => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
        };

        $layoutConfig['right_column_order_key'] = $rightKey;
        $layoutConfig['right_column_order'] = $rightOrder;

        if (!empty($layoutConfig['slots'])) {
            $layoutConfig['slots'] = \App\Services\FrameSlotDetector::assignSlotPoses(
                $layoutConfig['slots'],
                $layoutType,
                $rightOrder,
                $this->pose_count ?? 4
            );
        }

        Frame::where('master_frame_id', $this->id)
            ->orWhere('name', $this->name)
            ->update([
                'master_frame_id' => $this->id,
                'name'            => $this->name,
                'asset_url'       => $this->asset_url,
                'pose_count'      => $this->pose_count,
                'layout_config'   => $layoutConfig,
                'active'          => $this->is_active,
            ]);
    }
}

