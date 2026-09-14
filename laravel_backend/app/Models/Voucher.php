<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Validation\ValidationException;

class Voucher extends Model
{
    protected $fillable = [
        'cafe_id', 'event_id', 'name', 'code', 'type', 'value',
        'max_discount', 'minimum_purchase', 'quota', 'used_count',
        'per_device_limit', 'starts_at', 'expires_at', 'is_active', 'notes',
    ];

    protected $casts = [
        'value' => 'integer',
        'max_discount' => 'integer',
        'minimum_purchase' => 'integer',
        'quota' => 'integer',
        'used_count' => 'integer',
        'per_device_limit' => 'integer',
        'starts_at' => 'datetime',
        'expires_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    protected static function booted(): void
    {
        static::saving(function (Voucher $voucher): void {
            $voucher->code = strtoupper(trim($voucher->code));

            if (! in_array($voucher->type, ['full', 'fixed', 'percentage'], true)) {
                throw ValidationException::withMessages(['type' => 'Tipe voucher tidak valid.']);
            }
            if ($voucher->type === 'full') {
                $voucher->value = 0;
                $voucher->max_discount = null;
            } elseif ((int) $voucher->value < 1) {
                throw ValidationException::withMessages(['value' => 'Nilai voucher harus lebih dari nol.']);
            }
            if ($voucher->type === 'percentage' && (int) $voucher->value > 100) {
                throw ValidationException::withMessages(['value' => 'Persentase voucher maksimal 100%.']);
            }
            if ($voucher->starts_at && $voucher->expires_at && $voucher->expires_at->lte($voucher->starts_at)) {
                throw ValidationException::withMessages(['expires_at' => 'Waktu berakhir harus setelah waktu mulai.']);
            }

            if ($voucher->event_id && ! Event::whereKey($voucher->event_id)->where('cafe_id', $voucher->cafe_id)->exists()) {
                throw ValidationException::withMessages(['event_id' => 'Event harus berasal dari cafe voucher yang sama.']);
            }
        });
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function redemptions(): HasMany
    {
        return $this->hasMany(VoucherRedemption::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }
}
