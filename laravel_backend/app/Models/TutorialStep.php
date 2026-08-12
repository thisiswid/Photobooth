<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TutorialStep extends Model
{
    protected $fillable = ['screen_config_id', 'sort_order', 'title', 'description', 'image_url', 'active'];

    protected $casts = ['active' => 'boolean'];

    public function screenConfig(): BelongsTo
    {
        return $this->belongsTo(ScreenConfig::class);
    }
}
