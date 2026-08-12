<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Frame extends Model
{
    protected $fillable = [
        'name', 'slug', 'file_path', 'preview_path',
        'category', 'is_active', 'sort_order',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function sessions(): HasMany
    {
        return $this->hasMany(PhotoSession::class);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true)->orderBy('sort_order');
    }
}
