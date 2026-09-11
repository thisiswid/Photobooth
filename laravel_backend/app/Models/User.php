<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    use HasFactory, Notifiable, HasApiTokens;

    protected $fillable = [
        'cafe_id',
        'name',
        'email',
        'password',
        'role', // 'super_admin', 'admin', 'operator', 'viewer'
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === 'super_admin';
    }

    public function isCafeAdmin(): bool
    {
        return in_array($this->role, ['admin', 'operator', 'viewer']);
    }

    public function canAccessPanel(Panel $panel): bool
    {
        if ($panel->getId() === 'super_admin') {
            return $this->isSuperAdmin();
        }

        if ($panel->getId() === 'admin') {
            if ($this->isSuperAdmin()) {
                return true;
            }

            if ($this->isCafeAdmin()) {
                // Wajib terikat ke satu cafe. Sebelumnya cabang ini
                // mengembalikan true untuk pengguna tanpa cafe_id, dan karena
                // semua getEloquentQuery() memfilter dengan
                // `if ($cafeId = auth()->user()?->cafe_id)`, pengguna seperti
                // itu justru melihat data seluruh tenant.
                if (!$this->cafe_id || !$this->cafe) {
                    return false;
                }

                return $this->cafe->isSubscriptionActive();
            }

            return false;
        }

        return false;
    }
}
