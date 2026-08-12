<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Event extends Model
{
    protected $fillable = ['name', 'description', 'starts_at', 'ends_at', 'active'];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at'   => 'datetime',
        'active'    => 'boolean',
    ];

    public function frames(): HasMany
    {
        return $this->hasMany(Frame::class);
    }

    public function filters(): HasMany
    {
        return $this->hasMany(Filter::class);
    }

    public function screenConfigs(): HasMany
    {
        return $this->hasMany(ScreenConfig::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(Session::class);
    }
}
