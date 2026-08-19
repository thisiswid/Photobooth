<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Frame extends Model
{
    protected $fillable = ['event_id', 'master_frame_id', 'name', 'asset_url', 'pose_count', 'layout_config', 'active'];

    protected $casts = ['active' => 'boolean', 'pose_count' => 'integer', 'layout_config' => 'array'];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function masterFrame(): BelongsTo
    {
        return $this->belongsTo(MasterFrame::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(Session::class);
    }
}
