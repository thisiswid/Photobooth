<?php

namespace App\Services;

use App\Models\Cafe;
use App\Models\Device;
use App\Models\OperationalAlert;
use App\Models\Payment;
use App\Models\User;
use App\Models\Withdrawal;
use Filament\Notifications\Notification;

class OperationalAlertService
{
    private array $seen = [];

    public function scan(): array
    {
        $this->seen = [];
        $this->scanOfflineDevices();
        $this->scanLicenses();
        $this->scanDeviceLimits();
        $this->scanPendingPayments();
        $this->scanReconciliationProblems();
        $this->scanPendingWithdrawals();
        $this->resolveMissingAlerts();

        return [
            'active' => OperationalAlert::where('status', 'active')->count(),
            'created_or_refreshed' => count($this->seen),
        ];
    }

    private function scanOfflineDevices(): void
    {
        Device::query()
            ->with('cafe.users')
            ->where('status', 'active')
            ->whereNotNull('installation_id')
            ->where(function ($query): void {
                $query->where('last_seen_at', '<=', now()->subMinutes(5))
                    ->orWhere(fn ($missing) => $missing->whereNull('last_seen_at')->where('activated_at', '<=', now()->subMinutes(10)));
            })
            ->each(function (Device $device): void {
                $this->detect(
                    "device_offline:{$device->id}",
                    'device_offline',
                    'danger',
                    'Mesin booth offline',
                    "{$device->name} tidak mengirim heartbeat lebih dari 5 menit.",
                    $device->cafe,
                    ['device_id' => $device->id, 'last_seen_at' => $device->last_seen_at?->toIso8601String()],
                );
            });
    }

    private function scanLicenses(): void
    {
        Cafe::query()
            ->with('users')
            ->where('status', 'active')
            ->whereNotNull('subscription_end_at')
            ->whereBetween('subscription_end_at', [now(), now()->addDays(7)])
            ->each(function (Cafe $cafe): void {
                $days = max(0, now()->diffInDays($cafe->subscription_end_at, false));
                $this->detect(
                    "license_expiring:{$cafe->id}",
                    'license_expiring',
                    'warning',
                    'Lisensi segera berakhir',
                    "Lisensi {$cafe->name} berakhir dalam {$days} hari.",
                    $cafe,
                    ['subscription_end_at' => $cafe->subscription_end_at?->toIso8601String()],
                );
            });

        Cafe::query()
            ->with('users')
            ->whereNotNull('subscription_end_at')
            ->where('subscription_end_at', '<=', now())
            ->each(fn (Cafe $cafe) => $this->detect(
                "license_expired:{$cafe->id}",
                'license_expired',
                'danger',
                'Lisensi telah berakhir',
                "Lisensi {$cafe->name} sudah berakhir.",
                $cafe,
                ['subscription_end_at' => $cafe->subscription_end_at?->toIso8601String()],
            ));
    }

    private function scanDeviceLimits(): void
    {
        Cafe::query()
            ->with('users')
            ->withCount(['devices as activated_devices_count' => fn ($query) => $query->whereNotNull('installation_id')])
            ->get()
            ->filter(fn (Cafe $cafe) => $cafe->activated_devices_count >= max(1, (int) $cafe->device_limit))
            ->each(fn (Cafe $cafe) => $this->detect(
                "device_limit:{$cafe->id}",
                'device_limit',
                'warning',
                'Slot perangkat penuh',
                "{$cafe->name} memakai {$cafe->activated_devices_count} dari {$cafe->device_limit} slot perangkat.",
                $cafe,
                ['used' => $cafe->activated_devices_count, 'limit' => $cafe->device_limit],
            ));
    }

    private function scanPendingPayments(): void
    {
        Payment::query()
            ->with('session.cafe.users')
            ->where('status', 'pending')
            ->where('is_simulated', false)
            ->whereNotNull('xendit_payment_id')
            ->whereBetween('created_at', [now()->subDays(7), now()->subMinutes(15)])
            ->each(function (Payment $payment): void {
                $cafe = $payment->session?->cafe;
                if (! $cafe) {
                    return;
                }
                $this->detect(
                    "payment_pending:{$payment->id}",
                    'payment_pending',
                    'warning',
                    'Pembayaran terlalu lama pending',
                    "Order {$payment->xendit_payment_id} belum selesai lebih dari 15 menit.",
                    $cafe,
                    ['payment_id' => $payment->id, 'order_id' => $payment->xendit_payment_id],
                );
            });
    }

    private function scanReconciliationProblems(): void
    {
        Payment::query()
            ->with('session.cafe.users')
            ->whereIn('reconciliation_status', ['mismatch', 'error'])
            ->where('last_gateway_check_at', '>=', now()->subDays(7))
            ->each(function (Payment $payment): void {
                $cafe = $payment->session?->cafe;
                if (! $cafe) {
                    return;
                }
                $this->detect(
                    "payment_reconciliation:{$payment->id}",
                    'payment_reconciliation',
                    'danger',
                    'Transaksi perlu diperiksa',
                    $payment->reconciliation_message ?: "Rekonsiliasi order {$payment->xendit_payment_id} bermasalah.",
                    $cafe,
                    ['payment_id' => $payment->id, 'order_id' => $payment->xendit_payment_id],
                );
            });
    }

    private function scanPendingWithdrawals(): void
    {
        Withdrawal::query()
            ->with('cafe.users')
            ->where('status', 'pending')
            ->where('created_at', '<=', now()->subDay())
            ->each(function (Withdrawal $withdrawal): void {
                $this->detect(
                    "withdrawal_pending:{$withdrawal->id}",
                    'withdrawal_pending',
                    'warning',
                    'Penarikan belum diproses',
                    "Pengajuan {$withdrawal->reference_no} belum diproses lebih dari 24 jam.",
                    $withdrawal->cafe,
                    ['withdrawal_id' => $withdrawal->id, 'reference_no' => $withdrawal->reference_no],
                );
            });
    }

    private function detect(
        string $fingerprint,
        string $category,
        string $severity,
        string $title,
        string $message,
        ?Cafe $cafe,
        array $context,
    ): void {
        $this->seen[$category][] = $fingerprint;
        $alert = OperationalAlert::firstOrNew(['fingerprint' => $fingerprint]);
        $isNew = ! $alert->exists;

        $alert->fill([
            'cafe_id' => $cafe?->id,
            'device_id' => $context['device_id'] ?? null,
            'payment_id' => $context['payment_id'] ?? null,
            'withdrawal_id' => $context['withdrawal_id'] ?? null,
            'category' => $category,
            'severity' => $severity,
            'title' => $title,
            'message' => $message,
            'status' => 'active',
            'first_detected_at' => $alert->first_detected_at ?? now(),
            'last_detected_at' => now(),
            'resolved_at' => null,
            'context' => $context,
        ]);

        $shouldNotify = $isNew || ! $alert->last_notified_at || $alert->last_notified_at->lte(now()->subHours(6));
        if ($shouldNotify) {
            $alert->last_notified_at = now();
        }
        $alert->save();

        if ($shouldNotify) {
            $this->notify($alert, $cafe);
        }
    }

    private function notify(OperationalAlert $alert, ?Cafe $cafe): void
    {
        $recipients = User::query()->where('role', 'super_admin')->get();
        if ($cafe) {
            $recipients = $recipients->concat($cafe->users)->unique('id')->values();
        }
        if ($recipients->isEmpty()) {
            return;
        }

        $notification = Notification::make()->title($alert->title)->body($alert->message);
        $notification = match ($alert->severity) {
            'danger' => $notification->danger(),
            'success' => $notification->success(),
            'info' => $notification->info(),
            default => $notification->warning(),
        };
        $notification->sendToDatabase($recipients);
    }

    private function resolveMissingAlerts(): void
    {
        foreach (['device_offline', 'license_expiring', 'license_expired', 'device_limit', 'payment_pending', 'payment_reconciliation', 'withdrawal_pending'] as $category) {
            $query = OperationalAlert::where('category', $category)->where('status', 'active');
            $fingerprints = $this->seen[$category] ?? [];
            if ($fingerprints !== []) {
                $query->whereNotIn('fingerprint', $fingerprints);
            }
            $query->update(['status' => 'resolved', 'resolved_at' => now()]);
        }
    }
}
