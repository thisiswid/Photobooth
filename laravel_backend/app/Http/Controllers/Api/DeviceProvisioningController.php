<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\ErrorLog;
use App\Models\Event;
use App\Models\Filter;
use App\Models\Frame;
use App\Models\ScreenConfig;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeviceProvisioningController extends Controller
{
    /**
     * Inisialisasi & Aktivasi Device Kiosk saat pertama kali dipasang di Cafe.
     */
    public function activate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'device_key' => 'required|string',
            'platform'   => 'nullable|string',
            'app_version'=> 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Parameter aktivasi tidak valid',
                'errors'  => $validator->errors(),
            ], 422);
        }

        $deviceKey = trim($request->device_key);
        $device = Device::where('device_key', $deviceKey)
            ->with(['cafe', 'event'])
            ->first();

        // ── Fallback 1: Jika input adalah Kode Lisensi Cafe (Code / Identifier) ──
        if (!$device) {
            $cafe = \App\Models\Cafe::where('code', $deviceKey)
                ->orWhere('code', strtoupper($deviceKey))
                ->orWhere('slug', strtolower($deviceKey))
                ->first();

            if ($cafe) {
                $device = Device::where('cafe_id', $cafe->id)->first();
                if (!$device) {
                    $device = Device::create([
                        'cafe_id'    => $cafe->id,
                        'name'       => $cafe->name . ' - Kiosk Utama',
                        'device_key' => $deviceKey,
                        'platform'   => $request->platform ?? 'android',
                        'status'     => 'active',
                        'last_seen_at' => now(),
                    ]);
                } else {
                    $device->update([
                        'device_key' => $deviceKey,
                        'platform'   => $request->platform ?? $device->platform ?? 'android',
                        'status'     => 'active',
                        'last_seen_at' => now(),
                    ]);
                }
                $device->load(['cafe', 'event']);
            }
        }

        if (!$device) {
            return response()->json([
                'success' => false,
                'message' => 'Device Key / Kode Lisensi tidak ditemukan atau belum didaftarkan oleh Super Admin.',
            ], 404);
        }

        if (!$device->cafe) {
            return response()->json([
                'success' => false,
                'message' => 'Perangkat ini belum dialokasikan ke Cafe / Tenant manapun.',
            ], 400);
        }

        if (!$device->cafe->isSubscriptionActive()) {
            return response()->json([
                'success' => false,
                'message' => 'Lisensi / Masa aktif kemitraan Cafe ini sedang nonaktif atau kedaluwarsa.',
                'cafe_status' => $device->cafe->status,
            ], 403);
        }

        // Update telemetri device
        $device->update([
            'platform'     => $request->platform ?? $device->platform ?? 'android',
            'ip_address'   => $request->ip(),
            'last_seen_at' => now(),
            'status'       => 'active',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Aktivasi mesin berhasil!',
            'data'    => [
                'device' => [
                    'id'          => $device->id,
                    'name'        => $device->name,
                    'device_key'  => $device->device_key,
                    'platform'    => $device->platform,
                ],
                'cafe' => [
                    'id'          => $device->cafe->id,
                    'name'        => $device->cafe->name,
                    'code'        => $device->cafe->code,
                    'address'     => $device->cafe->address,
                    'logo_url'    => $device->cafe->logo_path ? asset('storage/' . $device->cafe->logo_path) : null,
                ],
                'event' => $device->event ? [
                    'id'   => $device->event->id,
                    'name' => $device->event->name,
                ] : null,
            ],
        ]);
    }

    /**
     * Mengambil seluruh konfigurasi dinamis (Theme, Frames, Filters, Screens, Pricing)
     * untuk sinkronisasi tampilan kiosk cafe.
     */
    public function config(string $deviceKey): JsonResponse
    {
        $deviceKey = trim($deviceKey);
        $device = Device::where('device_key', $deviceKey)
            ->with(['cafe', 'event'])
            ->first();

        // ── Fallback: Cari via Cafe Code ──
        if (!$device) {
            $cafe = \App\Models\Cafe::where('code', $deviceKey)
                ->orWhere('code', strtoupper($deviceKey))
                ->orWhere('slug', strtolower($deviceKey))
                ->first();

            if ($cafe) {
                $device = Device::where('cafe_id', $cafe->id)->first();
                if (!$device) {
                    $device = Device::create([
                        'cafe_id'    => $cafe->id,
                        'name'       => $cafe->name . ' - Kiosk Utama',
                        'device_key' => $deviceKey,
                        'platform'   => 'android',
                        'status'     => 'active',
                        'last_seen_at' => now(),
                    ]);
                }
                $device->load(['cafe', 'event']);
            }
        }

        if (!$device || !$device->cafe) {
            return response()->json([
                'success' => false,
                'message' => 'Perangkat tidak valid.',
            ], 404);
        }

        $cafe = $device->cafe;

        // Ambil event aktif untuk cafe ini (atau fallback event pertama)
        $event = $device->event ?? Event::where('cafe_id', $cafe->id)->where('active', true)->first()
            ?? Event::where('cafe_id', $cafe->id)->latest()->first();

        // Ambil Frames aktif
        $framesQuery = Frame::where('active', true);
        if ($event) {
            $framesQuery->where('event_id', $event->id);
        }
        $frames = $framesQuery->get()->map(function (Frame $frame) {
            $config = $frame->layout_config ?? [];
            return [
                'id'                 => $frame->id,
                'name'               => $frame->name,
                'asset_url'          => $frame->asset_url ? asset('storage/' . $frame->asset_url) : $frame->asset_url,
                'pose_count'         => $frame->pose_count ?? 4,
                'layout_type'        => $config['layout_type'] ?? 'single',
                'slots'              => $config['slots'] ?? [],
                'right_column_order' => $config['right_column_order'] ?? null,
            ];
        });

        // Ambil Filters aktif
        $filtersQuery = Filter::where('active', true)->orderBy('sort_order');
        if ($event) {
            $filtersQuery->where('event_id', $event->id);
        }
        $filters = $filtersQuery->get()->map(function (Filter $filter) {
            return [
                'id'            => $filter->id,
                'name'          => $filter->name,
                'thumbnail_url' => $filter->thumbnail_url ? asset('storage/' . $filter->thumbnail_url) : null,
                'parameters'    => is_string($filter->parameters) ? json_decode($filter->parameters, true) : $filter->parameters,
                'sort_order'    => $filter->sort_order,
            ];
        });

        // Ambil Screen Content (Welcome & Tutorial)
        $screens = [];
        if ($event) {
            $screenConfigs = ScreenConfig::where('event_id', $event->id)
                ->whereIn('status', ['active', 'published'])
                ->with('tutorialSteps')
                ->get();

            foreach ($screenConfigs as $sc) {
                $screens[$sc->screen_type] = [
                    'title'          => $sc->title,
                    'description'    => $sc->description,
                    'background_url' => $sc->background_url ? asset('storage/' . $sc->background_url) : null,
                    'button_text'    => $sc->button_text ?? 'Mulai Foto',
                    'tutorial_steps' => $sc->tutorialSteps->map(fn ($step) => [
                        'title'       => $step->title,
                        'description' => $step->description,
                        'image_url'   => $step->image_url ? asset('storage/' . $step->image_url) : null,
                        'sort_order'  => $step->sort_order,
                    ]),
                ];
            }
        }

        $timerSetting = \App\Models\TimerSetting::resolveForCafe($cafe->id);

        return response()->json([
            'success' => true,
            'message' => 'OK',
            'data'    => [
                'cafe' => [
                    'id'                  => $cafe->id,
                    'name'                => $cafe->name,
                    'code'                => $cafe->code,
                    'logo_url'            => $cafe->logo_path ? asset('storage/' . $cafe->logo_path) : null,
                    'is_ai_enabled'       => (bool) ($cafe->is_ai_enabled ?? true),
                    'show_kiosk_settings' => (bool) ($cafe->show_kiosk_settings ?? true),
                    'theme'    => [
                        'primary_color' => '#D97706',
                        'accent_color'  => '#78350F',
                    ],
                ],
                'pricing' => [
                    'session_price'        => (int) ($cafe->session_price ?? 25000),
                    'currency'             => 'IDR',
                    'default_print_copies' => 2,
                ],
                'hardware_defaults' => [
                    'countdown_seconds'   => $timerSetting->camera_countdown_seconds,
                    'max_retakes'         => 1,
                    'auto_print'          => true,
                    'show_kiosk_settings' => (bool) ($cafe->show_kiosk_settings ?? true),
                ],
                'timers' => [
                    'camera_countdown_seconds'      => $timerSetting->camera_countdown_seconds,
                    'session_timeout_seconds'       => $timerSetting->session_timeout_seconds,
                    'payment_timeout_seconds'       => $timerSetting->payment_timeout_seconds,
                    'result_screen_timeout_seconds' => $timerSetting->result_screen_timeout_seconds,
                    'retake_timeout_seconds'        => $timerSetting->retake_timeout_seconds,
                ],
                'event'   => $event ? ['id' => $event->id, 'name' => $event->name] : null,
                'frames'  => $frames,
                'filters' => $filters,
                'screens' => empty($screens) ? (object) [] : $screens,
            ],
        ]);
    }

    /**
     * Heartbeat & Laporan Telemetri Real-time dari Mesin.
     */
    public function heartbeat(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'device_key'     => 'required|string',
            'printer_status' => 'nullable|string', // ready, paper_low, out_of_paper, offline, error
            'camera_status'  => 'nullable|string', // connected, disconnected, error
            'app_version'    => 'nullable|string',
            'error_message'  => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Invalid data'], 422);
        }

        $deviceKey = trim($request->device_key);
        $device = Device::where('device_key', $deviceKey)->first();
        if (!$device) {
            $cafe = \App\Models\Cafe::where('code', $deviceKey)
                ->orWhere('code', strtoupper($deviceKey))
                ->orWhere('slug', strtolower($deviceKey))
                ->first();
            if ($cafe) {
                $device = Device::where('cafe_id', $cafe->id)->first();
            }
        }
        if (!$device) {
            return response()->json(['success' => false, 'message' => 'Device not found'], 404);
        }

        $device->update([
            'ip_address'   => $request->ip(),
            'last_seen_at' => now(),
            'status'       => 'active',
        ]);

        // Jika ada insiden hardware dilaporkan via heartbeat, otomatis catat ke ErrorLog
        if (!empty($request->error_message) || $request->printer_status === 'error' || $request->camera_status === 'error') {
            ErrorLog::create([
                'cafe_id'     => $device->cafe_id,
                'device_id'   => $device->device_key ?? (string) $device->id,
                'event_id'    => $device->event_id ?? \App\Models\Event::where('cafe_id', $device->cafe_id)->where('active', true)->first()?->id ?? \App\Models\Event::first()?->id,
                'category'    => $request->camera_status === 'error' ? 'camera' : ($request->printer_status === 'error' ? 'hardware' : 'system'),
                'level'       => 'warning',
                'title'       => 'Heartbeat Telemetry Alert: ' . ($request->error_message ?? 'Hardware status error'),
                'message'     => "Printer: {$request->printer_status}, Camera: {$request->camera_status}",
                'context'     => [
                    'ip'          => $request->ip(),
                    'app_version' => $request->app_version,
                ],
                'ip_address'  => $request->ip(),
            ]);
        }

        return response()->json([
            'success'   => true,
            'timestamp' => now()->toIso8601String(),
            'message'   => 'Heartbeat recorded successfully.',
        ]);
    }
}
