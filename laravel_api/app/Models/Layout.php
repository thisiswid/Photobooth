<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Layout extends Model
{
    protected $fillable = [
        'name', 'slug', 'photo_count', 'orientation',
        'preview_path', 'config', 'is_active',
    ];

    protected $casts = [
        'config' => 'array',
        'is_active' => 'boolean',
        'photo_count' => 'integer',
    ];

    public function sessions(): HasMany
    {
        return $this->hasMany(PhotoSession::class);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
