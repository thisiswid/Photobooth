<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Withdrawal extends Model
{
    use HasFactory;

    protected $fillable = [
        'reference_no',
        'cafe_id',
        'user_id',
        'amount',
        'bank_name',
        'bank_account_number',
        'bank_account_holder',
        'status',
        'proof_of_transfer_path',
        'notes',
        'processed_by',
        'processed_at',
    ];

    protected $casts = [
        'amount'       => 'integer',
        'processed_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (Withdrawal $withdrawal) {
            if (empty($withdrawal->reference_no)) {
                $withdrawal->reference_no = 'WD-' . date('Ymd') . '-' . strtoupper(Str::random(5));
            }
        });
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function processor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isApproved(): bool
    {
        return $this->status === 'approved';
    }

    public function isRejected(): bool
    {
        return $this->status === 'rejected';
    }
}
