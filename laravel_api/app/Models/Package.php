<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Package extends Model
{
    protected $fillable = [
        'name', 'slug', 'photo_count', 'print_count',
        'price', 'description', 'is_active', 'sort_order',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'photo_count' => 'integer',
        'print_count' => 'integer',
        'price' => 'integer',
        'sort_order' => 'integer',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function sessions(): HasMany
    {
        return $this->hasMany(PhotoSession::class);
    }

    // ── Scopes ────────────────────────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('is_active', true)->orderBy('sort_order');
    }

    // ── Accessors ─────────────────────────────────────────────────────────────

    public function getPriceFormattedAttribute(): string
    {
        return 'Rp' . number_format($this->price, 0, ',', '.');
    }
}
