<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Sticker extends Model
{
    protected $fillable = ['name', 'slug', 'file_path', 'category', 'is_active'];

    protected $casts = ['is_active' => 'boolean'];

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByCategory($query, string $category)
    {
        return $query->where('category', $category);
    }
}
