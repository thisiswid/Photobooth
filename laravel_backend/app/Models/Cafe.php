<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;

class Cafe extends Model
{
    use HasFactory, \App\Traits\LogsActivity;

    protected $fillable = [
        'name',
        'slug',
        'code',
        'pic_name',
        'pic_phone',
        'pic_email',
        'address',
        'status',
        'is_ai_enabled',
        'show_kiosk_settings',
        'subscription_end_at',
        'device_limit',
        'revenue_share_percentage',
        'session_price',
        'logo_path',
        'notes',
        'bank_name',
        'bank_account_number',
        'bank_account_holder',
    ];

    protected $casts = [
        'is_ai_enabled'            => 'boolean',
        'show_kiosk_settings'      => 'boolean',
        'subscription_end_at'      => 'datetime',
        'device_limit'             => 'integer',
        'revenue_share_percentage' => 'decimal:2',
        'session_price'            => 'integer',
    ];

    protected static function booted(): void
    {
        static::created(function (Cafe $cafe) {
            if ($cafe->devices()->count() === 0) {
                $cafe->devices()->create([
                    'name'       => $cafe->name . ' - Kiosk Utama',
                    'device_key' => $cafe->code,
                    'platform'   => 'android',
                    'status'     => 'active',
                ]);
            }
        });
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(Event::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(Session::class);
    }

    public function errorLogs(): HasMany
    {
        return $this->hasMany(ErrorLog::class);
    }

    public function payments(): HasManyThrough
    {
        return $this->hasManyThrough(Payment::class, Session::class, 'cafe_id', 'session_id');
    }

    public function timerSettings(): HasMany
    {
        return $this->hasMany(TimerSetting::class);
    }

    public function withdrawals(): HasMany
    {
        return $this->hasMany(Withdrawal::class);
    }

    public function activityLogs(): HasMany
    {
        return $this->hasMany(ActivityLog::class);
    }

    // ─── Financial & Withdrawal Balance Calculations ──────────────────────────

    /**
     * Total omset kotor dari pembayaran berstatus 'paid'
     */
    public function getTotalRevenueAttribute(): int
    {
        return (int) $this->payments()->where('payments.status', 'paid')->sum('amount');
    }

    /**
     * Potongan fee / komisi bagi hasil platform
     */
    public function getPlatformFeeAttribute(): int
    {
        // Potongan persentase dinonaktifkan sementara. Kolom lama tetap
        // dipertahankan agar dapat diaktifkan kembali lewat migrasi/fitur nanti.
        return 0;
    }

    /**
     * Hak omset bersih milik cafe (setelah dipotong komisi platform)
     */
    public function getNetRevenueAttribute(): int
    {
        return $this->total_revenue - $this->platform_fee;
    }

    /**
     * Total dana yang sudah berhasil dicairkan (status 'approved')
     */
    public function getTotalWithdrawnAttribute(): int
    {
        return (int) $this->withdrawals()->where('status', 'approved')->sum('amount');
    }

    /**
     * Total dana yang sedang dalam proses pengajuan (status 'pending')
     */
    public function getPendingWithdrawalAttribute(): int
    {
        return (int) $this->withdrawals()->where('status', 'pending')->sum('amount');
    }

    /**
     * Saldo bersih yang siap ditarik saat ini
     */
    public function getAvailableBalanceAttribute(): int
    {
        $available = $this->net_revenue - $this->total_withdrawn - $this->pending_withdrawal;
        return max(0, $available);
    }

    public function isSubscriptionActive(): bool
    {
        if ($this->status !== 'active') {
            return false;
        }
        if ($this->subscription_end_at === null) {
            return true; // Unlimited / Lifetime
        }
        return $this->subscription_end_at->isFuture();
    }

    public function hasAvailableDeviceSlot(): bool
    {
        return $this->devices()->count() < max(1, (int) $this->device_limit);
    }

    public function getDeviceUsageLabelAttribute(): string
    {
        return $this->devices()->whereNotNull('installation_id')->count()
            . ' / ' . max(1, (int) $this->device_limit);
    }
}
