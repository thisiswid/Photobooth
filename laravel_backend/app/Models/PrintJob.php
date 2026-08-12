<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrintJob extends Model
{
    protected $fillable = ['session_id', 'printer', 'status', 'printed_at'];

    protected $casts = ['printed_at' => 'datetime'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(Session::class);
    }
}
