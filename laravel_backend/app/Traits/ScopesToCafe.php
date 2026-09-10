<?php

namespace App\Traits;

use App\Models\Event;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

/**
 * Isolasi tenant untuk Admin REST API.
 *
 * Sebelum trait ini ada, sebelas controller di app/Http/Controllers/Api/Admin
 * melakukan query polos tanpa satu pun penyebutan cafe_id, sehingga satu token
 * Sanctum milik operator cafe manapun membuka data seluruh cafe di platform.
 *
 * Super admin sengaja dibiarkan lintas tenant; peran lain wajib terikat cafe.
 */
trait ScopesToCafe
{
    protected function actor(): ?User
    {
        $user = auth()->user();
        return $user instanceof User ? $user : null;
    }

    protected function isSuperAdmin(): bool
    {
        return (bool) $this->actor()?->isSuperAdmin();
    }

    /**
     * cafe_id yang harus dipakai, atau null untuk super admin (lintas tenant).
     * Akun non-super-admin tanpa cafe_id ditolak, bukan dianggap "lihat semua".
     */
    protected function cafeId(): ?int
    {
        if ($this->isSuperAdmin()) {
            return null;
        }

        $cafeId = $this->actor()?->cafe_id;
        abort_if(!$cafeId, 403, 'Akun ini tidak terikat ke cafe manapun.');

        return (int) $cafeId;
    }

    /** Model yang punya kolom cafe_id sendiri (Event, Device, Session, ErrorLog, User). */
    protected function scopeOwn(Builder $query): Builder
    {
        if ($cafeId = $this->cafeId()) {
            $query->where('cafe_id', $cafeId);
        }
        return $query;
    }

    /** Model yang tenant-nya lewat event (Frame, Filter, ScreenConfig). */
    protected function scopeViaEvent(Builder $query): Builder
    {
        if ($cafeId = $this->cafeId()) {
            $query->whereHas('event', fn ($q) => $q->where('cafe_id', $cafeId));
        }
        return $query;
    }

    /** Model yang tenant-nya lewat sesi (Payment, Result, PrintJob). */
    protected function scopeViaSession(Builder $query): Builder
    {
        if ($cafeId = $this->cafeId()) {
            $query->whereHas('session', fn ($q) => $q->where('cafe_id', $cafeId));
        }
        return $query;
    }

    /**
     * Tolak record milik tenant lain. Memakai 404, bukan 403, supaya keberadaan
     * record tenant lain tidak bisa dipetakan lewat beda kode status.
     */
    protected function guardCafe(?int $recordCafeId): void
    {
        $cafeId = $this->cafeId();
        if ($cafeId === null) {
            return;
        }

        abort_if((int) $recordCafeId !== $cafeId, 404, 'Data tidak ditemukan.');
    }

    /** Pastikan event_id yang dikirim di body memang milik cafe pemanggil. */
    protected function guardEventId(?int $eventId): void
    {
        $cafeId = $this->cafeId();
        if ($cafeId === null || $eventId === null) {
            return;
        }

        $ok = Event::where('id', $eventId)->where('cafe_id', $cafeId)->exists();
        abort_if(!$ok, 404, 'Event tidak ditemukan.');
    }

    /**
     * Suntik cafe_id pemanggil ke data yang akan disimpan, supaya record baru
     * tidak lahir tanpa tenant dan menjadi data yatim.
     */
    protected function withCafeId(array $data): array
    {
        if ($cafeId = $this->cafeId()) {
            $data['cafe_id'] = $cafeId;
        }
        return $data;
    }

    /** Aksi yang hanya boleh dilakukan admin cafe atau super admin. */
    protected function requireAdmin(): void
    {
        $user = $this->actor();
        abort_if(
            !$user || !in_array($user->role, ['super_admin', 'admin'], true),
            403,
            'Aksi ini hanya untuk admin.'
        );
    }
}
