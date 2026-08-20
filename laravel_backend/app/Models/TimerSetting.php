<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TimerSetting extends Model
{
    protected $fillable = [
        'cafe_id',
        'event_id',
        'name',
        'camera_countdown_seconds',
        'session_timeout_seconds',
        'payment_timeout_seconds',
        'result_screen_timeout_seconds',
        'retake_timeout_seconds',
        'is_active',
    ];

    protected $casts = [
        'camera_countdown_seconds'      => 'integer',
        'session_timeout_seconds'       => 'integer',
        'payment_timeout_seconds'       => 'integer',
        'result_screen_timeout_seconds' => 'integer',
        'retake_timeout_seconds'        => 'integer',
        'is_active'                     => 'boolean',
    ];

    public function cafe(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function event(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    /**
     * Resolve active timer setting for a cafe or fallback to global defaults.
     */
    public static function resolveForCafe(?int $cafeId = null): self
    {
        if ($cafeId) {
            $setting = static::where('cafe_id', $cafeId)->where('is_active', true)->first();
            if ($setting) {
                return $setting;
            }
        }

        // Global active setting or default instance
        return static::whereNull('cafe_id')->where('is_active', true)->first()
            ?? new static([
                'name'                          => 'Default Timer',
                'camera_countdown_seconds'      => 5,
                'session_timeout_seconds'       => 300,
                'payment_timeout_seconds'       => 120,
                'result_screen_timeout_seconds' => 60,
                'retake_timeout_seconds'        => 60,
                'is_active'                     => true,
            ]);
    }
}
