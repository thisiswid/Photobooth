<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ScreenConfig extends Model
{
    protected $fillable = [
        'event_id', 'screen_type', 'status',
        'title', 'description', 'background_url', 'button_text', 'version',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function tutorialSteps(): HasMany
    {
        return $this->hasMany(TutorialStep::class)->orderBy('sort_order');
    }
}
