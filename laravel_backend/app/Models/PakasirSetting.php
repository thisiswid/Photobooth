<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PakasirSetting extends Model
{
    protected $fillable = ['project_slug', 'api_key', 'is_enabled'];

    protected $casts = [
        'api_key' => 'encrypted',
        'is_enabled' => 'boolean',
    ];
}
