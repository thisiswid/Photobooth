<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * Represents a photobooth session.
 *
 * Lifecycle: pending → active → processing → result_ready → finished | timeout
 * Timer: expires_at = started_at + 5 minutes (set when session starts after PAID).
 */
class Session extends Model
{
    protected $table = 'photo_sessions';

    protected $fillable = [
        'event_id',
        'frame_id',
        'filter_id',
        'device_id',
        'status',
        'selected_filter',
        'retake_count',
        'started_at',
        'expires_at',
        'finished_at',
    ];

    protected $casts = [
        'started_at'   => 'datetime',
        'expires_at'   => 'datetime',
        'finished_at'  => 'datetime',
        'retake_count' => 'integer',
    ];

    // ── Relationships ──────────────────────────────────────────────────────────

    public function event(): BelongsTo    { return $this->belongsTo(Event::class); }
    public function frame(): BelongsTo    { return $this->belongsTo(Frame::class); }
    public function filter(): BelongsTo   { return $this->belongsTo(Filter::class); }
    public function device(): BelongsTo   { return $this->belongsTo(Device::class); }
    public function payment(): HasOne     { return $this->hasOne(Payment::class); }
    public function photos(): HasMany     { return $this->hasMany(Photo::class); }
    public function result(): HasOne      { return $this->hasOne(Result::class); }
    public function printJobs(): HasMany  { return $this->hasMany(PrintJob::class); }

    // ── Scopes ─────────────────────────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', 'active')
                     ->where('expires_at', '>', now());
    }

    public function scopeExpired($query)
    {
        return $query->where('expires_at', '<', now())
                     ->whereNotIn('status', ['finished', 'timeout']);
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }
}
