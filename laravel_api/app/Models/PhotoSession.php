<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PhotoSession extends Model
{
    protected $fillable = [
        'session_code', 'payment_status', 'package_id', 'layout_id',
        'frame_id', 'selected_filter', 'selected_sticker_ids', 'email',
        'started_at', 'expired_at', 'completed_at', 'total_photos',
        'strip_path', 'gif_path',
    ];

    protected $casts = [
        'selected_sticker_ids' => 'array',
        'started_at' => 'datetime',
        'expired_at' => 'datetime',
        'completed_at' => 'datetime',
        'total_photos' => 'integer',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function package(): BelongsTo
    {
        return $this->belongsTo(Package::class);
    }

    public function layout(): BelongsTo
    {
        return $this->belongsTo(Layout::class);
    }

    public function frame(): BelongsTo
    {
        return $this->belongsTo(Frame::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(Photo::class, 'session_id');
    }

    public function printJobs(): HasMany
    {
        return $this->hasMany(PrintJob::class, 'session_id');
    }

    // ── Scopes ────────────────────────────────────────────────────────────────

    public function scopeExpired($query)
    {
        return $query->where('expired_at', '<', now())
                     ->whereNull('completed_at');
    }

    public function scopeActive($query)
    {
        return $query->where('expired_at', '>', now())
                     ->where('payment_status', 'paid');
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    public function getGalleryUrlAttribute(): string
    {
        return config('photobooth.gallery_base_url') . '/' . $this->session_code;
    }

    public function getIsExpiredAttribute(): bool
    {
        return $this->expired_at && $this->expired_at->isPast();
    }

    // ── Static Helpers ────────────────────────────────────────────────────────

    /**
     * Generate a unique 8-character alphanumeric session code.
     */
    public static function generateCode(): string
    {
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        do {
            $code = '';
            for ($i = 0; $i < 8; $i++) {
                $code .= $chars[random_int(0, strlen($chars) - 1)];
            }
        } while (static::where('session_code', $code)->exists());

        return $code;
    }
}
