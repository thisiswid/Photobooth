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

    /**
     * Copy this MasterFrame into a specific Cafe's active Event.
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

        $frame = Frame::create([
            'event_id'      => $event->id,
            'name'          => $this->name,
            'asset_url'     => $this->asset_url,
            'pose_count'    => $this->pose_count,
            'layout_config' => $this->layout_config,
            'active'        => true,
        ]);

        $this->increment('usage_count');

        return $frame;
    }
}
