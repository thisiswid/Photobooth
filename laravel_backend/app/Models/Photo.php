<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Photo extends Model
{
    protected $fillable = ['session_id', 'type', 'file_url'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
