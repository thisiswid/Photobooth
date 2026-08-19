<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Device extends Model
{
    protected $fillable = [
        'cafe_id',
        'event_id',
        'name',
        'device_key',
        'platform',
        'ip_address',
        'status',
        'last_seen_at',
    ];

    protected $casts = [
        'last_seen_at' => 'datetime',
    ];

    public function cafe(): BelongsTo   { return $this->belongsTo(Cafe::class); }
    public function event(): BelongsTo  { return $this->belongsTo(Event::class); }
    public function sessions(): HasMany { return $this->hasMany(Session::class); }
}
