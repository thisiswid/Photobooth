<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;

class Cafe extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'code',
        'pic_name',
        'pic_phone',
        'pic_email',
        'address',
        'status',
        'is_ai_enabled',
        'subscription_end_at',
        'revenue_share_percentage',
        'logo_path',
        'notes',
    ];

    protected $casts = [
        'is_ai_enabled'            => 'boolean',
        'subscription_end_at'      => 'datetime',
        'revenue_share_percentage' => 'decimal:2',
    ];

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(Event::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(Session::class);
    }

    public function errorLogs(): HasMany
    {
        return $this->hasMany(ErrorLog::class);
    }

    public function payments(): HasManyThrough
    {
        return $this->hasManyThrough(Payment::class, Session::class, 'cafe_id', 'session_id');
    }

    public function timerSettings(): HasMany
    {
        return $this->hasMany(TimerSetting::class);
    }

    public function isSubscriptionActive(): bool
    {
        if ($this->status !== 'active') {
            return false;
        }
        if ($this->subscription_end_at === null) {
            return true; // Unlimited / Lifetime
        }
        return $this->subscription_end_at->isFuture();
    }
}
