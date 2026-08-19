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
     * Copy / Push this MasterFrame into a specific Cafe's active Event.
     */
    public function pushToCafe(Cafe $cafe): Frame
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

        $layoutConfig = $this->layout_config ?? [];
        $layoutType = $this->layout_type ?? ($layoutConfig['layout_type'] ?? 'single');
        $layoutConfig['layout_type'] = $layoutType;

        $rightKey = $layoutConfig['right_column_order_key'] ?? 'scrambled_1';
        $rightOrder = match($rightKey) {
            'scrambled_1' => ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1],
            'scrambled_2' => ($layoutType === 'double_8') ? [2, 3, 0, 1] : [1, 2, 0],
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

        $frame = Frame::updateOrCreate(
            [
                'event_id' => $event->id,
                'name'     => $this->name,
            ],
            [
                'master_frame_id' => $this->id,
                'asset_url'       => $this->asset_url,
                'pose_count'      => $this->pose_count,
                'layout_config'   => $layoutConfig,
                'active'          => $this->is_active,
            ]
        );

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

        // Update frames matched by master_frame_id or name
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
