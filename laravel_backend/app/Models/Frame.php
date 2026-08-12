<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Frame extends Model
{
    protected $fillable = ['event_id', 'name', 'asset_url', 'active'];

    protected $casts = ['active' => 'boolean'];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(Session::class);
    }
}
