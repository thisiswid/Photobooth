<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Result extends Model
{
    protected $fillable = ['session_id', 'final_url', 'gif_url', 'qr_token', 'expires_at'];

    protected $casts = ['expires_at' => 'datetime'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
