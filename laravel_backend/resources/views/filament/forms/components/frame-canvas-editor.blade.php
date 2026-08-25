@php
    $statePath = $getStatePath();
    $field = $this ?? null;
    $record = $getRecord();
    $initialState = $getState() ?? ($record?->layout_config ?? []);

    $imageFieldName = $getImageField();
    $imageVal = $get($imageFieldName) ?? $record?->asset_url;

    $initialImageUrl = null;
    if ($imageVal) {
        if (is_array($imageVal)) {
            $imageVal = reset($imageVal);
        }
        if (is_string($imageVal)) {
            if (str_starts_with($imageVal, 'http://') || str_starts_with($imageVal, 'https://')) {
                $initialImageUrl = $imageVal;
            } else {
                $initialImageUrl = '/storage/' . ltrim($imageVal, '/');
            }
        }
    }
@endphp

<style>
    .fbe-container { width: 100%; border: 1px solid #e5e7eb; border-radius: 16px; padding: 18px; background: #ffffff; box-sizing: border-box; }
    .dark .fbe-container { border-color: #1f2937; background: #111827; }
    .fbe-icon-sm { width: 14px !important; height: 14px !important; min-width: 14px !important; min-height: 14px !important; max-width: 14px !important; max-height: 14px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-icon-md { width: 18px !important; height: 18px !important; min-width: 18px !important; min-height: 18px !important; max-width: 18px !important; max-height: 18px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-icon-lg { width: 22px !important; height: 22px !important; min-width: 22px !important; min-height: 22px !important; max-width: 22px !important; max-height: 22px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 6px 12px; font-size: 12px; font-weight: 600; border-radius: 8px; cursor: pointer; transition: all 0.15s ease; text-decoration: none; border: 1px solid transparent; }
    .fbe-preset-btn { background: #f9fafb; border-color: #e5e7eb; color: #374151; }
    .fbe-preset-btn:hover { background: #f3f4f6; border-color: #d1d5db; color: #111827; }
    .dark .fbe-preset-btn { background: #1f2937; border-color: #374151; color: #d1d5db; }
    .dark .fbe-preset-btn:hover { background: #374151; color: #ffffff; }
    .fbe-primary-btn { background: #2563eb; color: #ffffff; border: none; }
    .fbe-primary-btn:hover { background: #1d4ed8; }
    .fbe-danger-btn { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
    .fbe-danger-btn:hover { background: #fee2e2; }
    .dark .fbe-danger-btn { background: #450a0a; color: #f87171; border-color: #7f1d1d; }
    .fbe-mockup { width: 100%; max-width: 360px; background: #18181b; border-radius: 32px; padding: 12px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.35); border: 4px solid #27272a; margin: 0 auto; box-sizing: border-box; }
    .fbe-notch { width: 90px; height: 12px; background: #27272a; border-radius: 9999px; margin: 0 auto 10px auto; display: flex; align-items: center; justify-content: center; gap: 6px; }
    .fbe-camera-dot { width: 6px; height: 6px; border-radius: 9999px; background: #3f3f46; }
    .fbe-speaker-bar { width: 34px; height: 4px; border-radius: 9999px; background: #3f3f46; }
    .fbe-home-bar { width: 100px; height: 4px; background: #3f3f46; border-radius: 9999px; margin: 10px auto 0 auto; opacity: 0.7; }
    .fbe-canvas-viewport { position: relative; border-radius: 20px; overflow: hidden; user-select: none; box-shadow: inset 0 2px 4px 0 rgba(0, 0, 0, 0.06); }
    .fbe-canvas-box { position: absolute; border-radius: 6px; display: flex; align-items: center; justify-content: center; user-select: none; cursor: move; box-sizing: border-box; }
    .fbe-badge { background: rgba(15, 23, 42, 0.9); color: #ffffff; padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 700; display: inline-flex; align-items: center; gap: 5px; pointer-events: none; border: 1px solid rgba(255,255,255,0.15); box-shadow: 0 4px 6px -1px rgba(0,0,0,0.2); }
    .fbe-handle { position: absolute; width: 14px; height: 14px; background: #2563eb; border: 2px solid #ffffff; border-radius: 9999px; box-shadow: 0 2px 4px rgba(0,0,0,0.2); z-index: 30; }
    .fbe-handle:hover { transform: scale(1.25); }
    .fbe-input { width: 100%; font-size: 12px; font-weight: 600; border-radius: 8px; border: 1px solid #d1d5db; background: #f9fafb; padding: 6px 10px; box-sizing: border-box; }
    .dark .fbe-input { border-color: #4b5563; background: #374151; color: #f3f4f6; }
</style>

<div
    x-data="frameCanvasEditor({
        state: $wire.entangle('{{ $statePath }}'),
        initialConfig: @js($initialState),
        imageUrl: @js($initialImageUrl),
    })"
    x-init="initEditor()"
    class="fbe-container"
>
    <!-- Top Header: Title & Quick Presets with Clean Line Icons -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; border-bottom: 1px solid #e5e7eb; padding-bottom: 14px; margin-bottom: 14px;">
        <div style="display: flex; align-items: center; gap: 10px;">
            <div style="padding: 6px; border-radius: 8px; background: #eff6ff; color: #2563eb; display: flex; align-items: center; justify-content: center;">
                <!-- Device / Kiosk Outline Icon -->
                <svg class="fbe-icon-lg" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <rect x="5" y="2" width="14" height="20" rx="3" ry="3"></rect>
                    <line x1="12" y1="18" x2="12.01" y2="18" stroke-width="2.5" stroke-linecap="round"></line>
                </svg>
            </div>
            <div>
                <div style="font-size: 13px; font-weight: 700; color: #111827;">Visual Frame Builder & Pose Editor</div>
                <div style="font-size: 11px; color: #6b7280;">Atur letak kotak foto, bentuk, dan nomor pose kamera langsung di atas kanvas.</div>
            </div>
        </div>

        <!-- Action Buttons with Outline Icons -->
        <div style="display: flex; align-items: center; gap: 8px;">
            <button
                type="button"
                @click="addSlot('portrait')"
                class="fbe-btn fbe-primary-btn"
            >
                <!-- Plus Outline Icon -->
                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
                </svg>
                <span>Tambah Kotak</span>
            </button>
            <button
                type="button"
                @click="clearAllSlots()"
                class="fbe-btn fbe-danger-btn"
            >
                <!-- Trash Outline Icon -->
                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                </svg>
                <span>Reset</span>
            </button>
        </div>
    </div>

    <!-- Quick Preset Badges Toolbar -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 8px; background: #f9fafb; padding: 10px; border-radius: 12px; border: 1px solid #e5e7eb; margin-bottom: 18px;">
        <span style="font-size: 11px; font-weight: 700; color: #6b7280; display: inline-flex; align-items: center; gap: 6px; padding: 0 4px;">
            <!-- Layers Outline Icon -->
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"/>
            </svg>
            Preset Cepat:
        </span>
        <button
            type="button"
            @click="applyPreset('strip_3')"
            class="fbe-btn fbe-preset-btn"
        >
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="7" y="2" width="10" height="20" rx="1"></rect>
                <line x1="7" y1="8" x2="17" y2="8"></line>
                <line x1="7" y1="14" x2="17" y2="14"></line>
            </svg>
            Strip 3 Foto
        </button>
        <button
            type="button"
            @click="applyPreset('strip_4')"
            class="fbe-btn fbe-preset-btn"
        >
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="7" y="2" width="10" height="20" rx="1"></rect>
                <line x1="7" y1="7" x2="17" y2="7"></line>
                <line x1="7" y1="12" x2="17" y2="12"></line>
                <line x1="7" y1="17" x2="17" y2="17"></line>
            </svg>
            Strip 4 Foto
        </button>
        <button
            type="button"
            @click="applyPreset('twin_6')"
            class="fbe-btn fbe-preset-btn"
        >
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="3" y="3" width="18" height="18" rx="2"></rect>
                <line x1="12" y1="3" x2="12" y2="21"></line>
                <line x1="3" y1="9" x2="21" y2="9"></line>
                <line x1="3" y1="15" x2="21" y2="15"></line>
            </svg>
            Kembar 6 Foto (2 Kolom)
        </button>
        <button
            type="button"
            @click="applyPreset('twin_8')"
            class="fbe-btn fbe-preset-btn"
        >
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="3" y="2" width="18" height="20" rx="2"></rect>
                <line x1="12" y1="2" x2="12" y2="22"></line>
                <line x1="3" y1="7" x2="21" y2="7"></line>
                <line x1="3" y1="12" x2="21" y2="12"></line>
                <line x1="3" y1="17" x2="21" y2="17"></line>
            </svg>
            Kembar 8 Foto (2 Kolom)
        </button>
        <button
            type="button"
            @click="applyPreset('grid_4')"
            class="fbe-btn fbe-preset-btn"
        >
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="3" y="3" width="7" height="7" rx="1"></rect>
                <rect x="14" y="3" width="7" height="7" rx="1"></rect>
                <rect x="3" y="14" width="7" height="7" rx="1"></rect>
                <rect x="14" y="14" width="7" height="7" rx="1"></rect>
            </svg>
            Grid 4 (2x2)
        </button>
    </div>

    <!-- Main Editor: Left Device Mockup + Right Inspector -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 24px; align-items: start;">
        <!-- Left: Interactive Mobile Canvas Shell -->
        <div style="display: flex; flex-direction: column; align-items: center;">
            <div class="fbe-mockup">
                <!-- Phone Notch -->
                <div class="fbe-notch">
                    <div class="fbe-camera-dot"></div>
                    <div class="fbe-speaker-bar"></div>
                </div>

                <!-- Canvas Viewport -->
                <div
                    x-ref="canvasContainer"
                    class="fbe-canvas-viewport"
                    :style="`width: ${displayW}px; height: ${displayH}px; max-width: 100%; margin: 0 auto; background: repeating-conic-gradient(#e5e7eb 0% 25%, #ffffff 0% 50%) 50% / 16px 16px;`"
                    @mousemove="onPointerMove($event)"
                    @mouseup="onPointerUp($event)"
                    @mouseleave="onPointerUp($event)"
                    @touchmove="onTouchMove($event)"
                    @touchend="onPointerUp($event)"
                >
                    <!-- Background Frame Image -->
                    <template x-if="imageUrl">
                        <img
                            :src="imageUrl"
                            style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; pointer-events: none;"
                            alt="Background Frame"
                            @load="onImageLoaded($event)"
                        />
                    </template>

                    <template x-if="!imageUrl">
                        <div style="position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #9ca3af; font-size: 11px; padding: 20px; text-align: center;">
                            <svg class="fbe-icon-lg" style="margin-bottom: 8px; opacity: 0.4;" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
                            </svg>
                            <span style="font-weight: 600;">Desain frame akan tampil di sini</span>
                            <span style="font-size: 10px; color: #9ca3af; margin-top: 4px;">Upload desain pada kolom di atas</span>
                        </div>
                    </template>

                    <!-- Interactive Slot Boxes -->
                    <template x-for="(slot, idx) in slots" :key="slot.id || idx">
                        <div
                            class="fbe-canvas-box"
                            :style="`left: ${toDispX(slot.x)}px; top: ${toDispY(slot.y)}px; width: ${toDispW(slot.w)}px; height: ${toDispH(slot.h)}px; ${
                                selectedIndex === idx
                                    ? 'border: 2px solid #2563eb; background: rgba(37, 99, 235, 0.25); box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.4); z-index: 20;'
                                    : 'border: 2px dashed #0284c7; background: rgba(14, 165, 233, 0.15); z-index: 10;'
                            }`"
                            @mousedown.stop="startDrag(idx, $event)"
                            @touchstart.stop="startTouchDrag(idx, $event)"
                            @click.stop="selectedIndex = idx"
                        >
                            <!-- Badge Label with Camera Icon -->
                            <div class="fbe-badge">
                                <svg class="fbe-icon-sm" style="color: #fbbf24;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                                </svg>
                                <span x-text="`#${idx + 1}`" style="color: #7dd3fc;"></span>
                                <span style="color: #94a3b8;">•</span>
                                <span x-text="`POSE ${slot.pose_index + 1}`" style="color: #fde047; font-weight: 800;"></span>
                            </div>

                            <!-- 4 Corner Resize Handles -->
                            <template x-if="selectedIndex === idx">
                                <div style="position: absolute; inset: 0; pointer-events: auto;">
                                    <!-- SE (Bottom Right) -->
                                    <div
                                        class="fbe-handle"
                                        style="right: -7px; bottom: -7px; cursor: se-resize;"
                                        @mousedown.stop="startResize(idx, 'se', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'se', $event)"
                                    ></div>
                                    <!-- SW (Bottom Left) -->
                                    <div
                                        class="fbe-handle"
                                        style="left: -7px; bottom: -7px; cursor: sw-resize;"
                                        @mousedown.stop="startResize(idx, 'sw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'sw', $event)"
                                    ></div>
                                    <!-- NE (Top Right) -->
                                    <div
                                        class="fbe-handle"
                                        style="right: -7px; top: -7px; cursor: ne-resize;"
                                        @mousedown.stop="startResize(idx, 'ne', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'ne', $event)"
                                    ></div>
                                    <!-- NW (Top Left) -->
                                    <div
                                        class="fbe-handle"
                                        style="left: -7px; top: -7px; cursor: nw-resize;"
                                        @mousedown.stop="startResize(idx, 'nw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'nw', $event)"
                                    ></div>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>

                <!-- Home Bar -->
                <div class="fbe-home-bar"></div>
            </div>
        </div>

        <!-- Right: Slot Details & Coordinate Controls -->
        <div style="display: flex; flex-direction: column; gap: 14px;">
            <!-- Summary Stats -->
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 14px; border-radius: 12px; background: #f9fafb; border: 1px solid #e5e7eb;">
                <div>
                    <div style="font-size: 11px; font-weight: 600; color: #6b7280;">Total Kotak Foto</div>
                    <div style="font-size: 18px; font-weight: 800; color: #111827;" x-text="`${slots.length} Kotak`"></div>
                </div>
                <div>
                    <div style="font-size: 11px; font-weight: 600; color: #6b7280;">Pose Kamera Diambil</div>
                    <div style="font-size: 18px; font-weight: 800; color: #d97706;" x-text="`${calculatedPoseCount} Pose`"></div>
                </div>
            </div>

            <!-- Active Slot Inspector Card -->
            <template x-if="selectedSlot">
                <div style="padding: 16px; border-radius: 14px; background: #ffffff; border: 2px solid #bfdbfe; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); display: flex; flex-direction: column; gap: 14px;">
                    <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #f3f4f6; padding-bottom: 10px;">
                        <div style="display: flex; align-items: center; gap: 6px;">
                            <span style="width: 8px; height: 8px; border-radius: 9999px; background: #2563eb;"></span>
                            <span style="font-size: 12px; font-weight: 700; color: #1e3a8a; text-transform: uppercase;" x-text="`Detail Kotak #${selectedIndex + 1}`"></span>
                        </div>
                        <div style="display: flex; align-items: center; gap: 6px;">
                            <button
                                type="button"
                                @click="duplicateSlot(selectedIndex)"
                                class="fbe-btn fbe-preset-btn"
                                style="padding: 4px 8px; font-size: 11px;"
                            >
                                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625V10.875c0-.621.504-1.125 1.125-1.125h3.375m7.5 7.5H19.875c.621 0 1.125-.504 1.125-1.125V5.625c0-.621-.504-1.125-1.125-1.125H9.875c-.621 0-1.125.504-1.125 1.125v3.375m7.5 7.5h-7.5"/>
                                </svg>
                                <span>Duplikat</span>
                            </button>
                            <button
                                type="button"
                                @click="deleteSlot(selectedIndex)"
                                class="fbe-btn fbe-danger-btn"
                                style="padding: 4px 8px; font-size: 11px;"
                            >
                                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                                </svg>
                                <span>Hapus</span>
                            </button>
                        </div>
                    </div>

                    <!-- Pose Number Select -->
                    <div>
                        <label style="display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 700; color: #374151; margin-bottom: 6px;">
                            <svg class="fbe-icon-sm" style="color: #d97706;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                            </svg>
                            Nomor Pose Kamera untuk Kotak Ini:
                        </label>
                        <select
                            x-model.number="selectedSlot.pose_index"
                            @change="onStateChange()"
                            class="fbe-input"
                        >
                            <template x-for="p in 8" :key="p">
                                <option :value="p - 1" x-text="`Pose #${p} (Foto Jepretan ke-${p})`"></option>
                            </template>
                        </select>
                        <div style="font-size: 10px; color: #6b7280; margin-top: 4px;">
                            Kotak dengan nomor pose yang sama akan otomatis terisi foto yang sama (misal foto kembar kiri & kanan).
                        </div>
                    </div>

                    <!-- Shape Selector -->
                    <div>
                        <label style="display: block; font-size: 11px; font-weight: 700; color: #374151; margin-bottom: 6px;">
                            Bentuk & Aspek Rasio Kotak:
                        </label>
                        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;">
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'portrait')"
                                class="fbe-btn fbe-preset-btn"
                                style="flex-direction: column; padding: 8px 4px; gap: 4px;"
                            >
                                <svg class="fbe-icon-md" style="color: #6b7280;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Potret (3:4)</span>
                            </button>
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'square')"
                                class="fbe-btn fbe-preset-btn"
                                style="flex-direction: column; padding: 8px 4px; gap: 4px;"
                            >
                                <svg class="fbe-icon-md" style="color: #6b7280;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Persegi (1:1)</span>
                            </button>
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'landscape')"
                                class="fbe-btn fbe-preset-btn"
                                style="flex-direction: column; padding: 8px 4px; gap: 4px;"
                            >
                                <svg class="fbe-icon-md" style="color: #6b7280;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="12" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Lanskap (4:3)</span>
                            </button>
                        </div>
                    </div>

                    <!-- Fine-tune Coordinates -->
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #6b7280;">Posisi X (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.x"
                                @input="onStateChange()"
                                class="fbe-input"
                            />
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #6b7280;">Posisi Y (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.y"
                                @input="onStateChange()"
                                class="fbe-input"
                            />
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #6b7280;">Lebar W (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.w"
                                @input="onStateChange()"
                                class="fbe-input"
                            />
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #6b7280;">Tinggi H (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.h"
                                @input="onStateChange()"
                                class="fbe-input"
                            />
                        </div>
                    </div>

                    <!-- Alignment Button -->
                    <button
                        type="button"
                        @click="centerHorizontally(selectedIndex)"
                        class="fbe-btn fbe-preset-btn"
                        style="width: 100%; padding: 8px;"
                    >
                        <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                            <line x1="3" y1="6" x2="21" y2="6"></line>
                            <line x1="6" y1="12" x2="18" y2="12"></line>
                            <line x1="3" y1="18" x2="21" y2="18"></line>
                        </svg>
                        <span>Ratakan Tengah (Center X)</span>
                    </button>
                </div>
            </template>

            <template x-if="!selectedSlot">
                <div style="padding: 24px; border-radius: 14px; background: #f9fafb; border: 2px dashed #e5e7eb; text-align: center; color: #6b7280; font-size: 11px;">
                    <svg class="fbe-icon-lg" style="margin: 0 auto 8px auto; opacity: 0.4;" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 8.608 3.978-2.94 1.134m-3.727 2.133L15.042 21.672zm-7.632-4.83a8.966 8.966 0 01-.84-2.842M3.93 11.02a8.966 8.966 0 011.05-3.324m2.132-2.825A8.966 8.966 0 0110.435 3.5"/>
                    </svg>
                    <div style="font-weight: 700; color: #374151;">Pilih salah satu kotak di kanvas</div>
                    <div style="font-size: 10px; color: #9ca3af; margin-top: 2px;">Klik kotak foto untuk mengatur nomor pose kamera atau mengubah bentuknya.</div>
                </div>
            </template>
        </div>
    </div>
</div>

<script>
    function frameCanvasEditor(params) {
        return {
            state: params.state,
            imageUrl: params.imageUrl,
            canvasW: 600,
            canvasH: 1800,
            displayW: 300,
            displayH: 900,
            slots: [],
            selectedIndex: 0,
            isDragging: false,
            isResizing: false,
            resizeHandle: null,
            dragStartMouseX: 0,
            dragStartMouseY: 0,
            dragStartSlot: null,

            initEditor() {
                const cfg = params.initialConfig || {};
                if (cfg.dimensions) {
                    this.canvasW = cfg.dimensions.w || 600;
                    this.canvasH = cfg.dimensions.h || 1800;
                }
                this.updateDisplayDimensions();

                if (Array.isArray(cfg.slots) && cfg.slots.length > 0) {
                    this.slots = cfg.slots.map((s, idx) => ({
                        id: s.id || 'slot_' + (idx + 1),
                        x: Math.round(Number(s.x) || 0),
                        y: Math.round(Number(s.y) || 0),
                        w: Math.round(Number(s.w) || 400),
                        h: Math.round(Number(s.h) || 300),
                        pose_index: Number(s.pose_index ?? idx),
                    }));
                } else {
                    // Default initial preset: 4 slots strip
                    this.applyPreset('strip_4', false);
                }

                if (this.slots.length > 0) {
                    this.selectedIndex = 0;
                }
                this.onStateChange();
            },

            get selectedSlot() {
                if (this.selectedIndex >= 0 && this.selectedIndex < this.slots.length) {
                    return this.slots[this.selectedIndex];
                }
                return null;
            },

            get calculatedPoseCount() {
                if (this.slots.length === 0) return 4;
                const maxPose = Math.max(...this.slots.map(s => Number(s.pose_index) || 0));
                return Math.max(1, maxPose + 1);
            },

            updateDisplayDimensions() {
                const maxW = 320;
                const ratio = this.canvasW / Math.max(1, this.canvasH);
                this.displayW = maxW;
                this.displayH = Math.round(maxW / ratio);
            },

            onImageLoaded(event) {
                const img = event.target;
                if (img && img.naturalWidth && img.naturalHeight) {
                    const oldW = this.canvasW;
                    const oldH = this.canvasH;
                    this.canvasW = img.naturalWidth;
                    this.canvasH = img.naturalHeight;
                    this.updateDisplayDimensions();

                    if (oldW > 0 && oldH > 0 && (oldW !== this.canvasW || oldH !== this.canvasH)) {
                        const scaleX = this.canvasW / oldW;
                        const scaleY = this.canvasH / oldH;
                        this.slots.forEach(s => {
                            s.x = Math.round(s.x * scaleX);
                            s.y = Math.round(s.y * scaleY);
                            s.w = Math.round(s.w * scaleX);
                            s.h = Math.round(s.h * scaleY);
                        });
                    }
                    this.onStateChange();
                }
            },

            toDispX(val) {
                return Math.round((val / this.canvasW) * this.displayW);
            },
            toDispY(val) {
                return Math.round((val / this.canvasH) * this.displayH);
            },
            toDispW(val) {
                return Math.round((val / this.canvasW) * this.displayW);
            },
            toDispH(val) {
                return Math.round((val / this.canvasH) * this.displayH);
            },

            applyPreset(presetKey, shouldSync = true) {
                const w = this.canvasW;
                const h = this.canvasH;
                const newSlots = [];

                if (presetKey === 'strip_3' || presetKey === 'strip_4') {
                    const count = presetKey === 'strip_3' ? 3 : 4;
                    const marginX = Math.round(w * 0.06);
                    const topPad = Math.round(h * 0.04);
                    const slotW = Math.round(w * 0.88);
                    const slotH = Math.round(h * (0.80 / count));
                    const gapY = Math.round(h * (0.12 / count));

                    for (let i = 0; i < count; i++) {
                        newSlots.push({
                            id: 'slot_' + (i + 1),
                            x: marginX,
                            y: topPad + i * (slotH + gapY),
                            w: slotW,
                            h: slotH,
                            pose_index: i
                        });
                    }
                } else if (presetKey === 'twin_6' || presetKey === 'twin_8') {
                    const rows = presetKey === 'twin_6' ? 3 : 4;
                    const colW = Math.round(w * 0.42);
                    const slotH = Math.round(h * (rows === 4 ? 0.20 : 0.26));
                    const leftX = Math.round(w * 0.055);
                    const rightX = Math.round(w * 0.525);
                    const topPad = Math.round(h * (rows === 4 ? 0.035 : 0.04));
                    const gapY = Math.round(h * (rows === 4 ? 0.025 : 0.035));

                    // Left Column: Pose 0..rows-1
                    for (let r = 0; r < rows; r++) {
                        newSlots.push({
                            id: 'slot_L' + (r + 1),
                            x: leftX,
                            y: topPad + r * (slotH + gapY),
                            w: colW,
                            h: slotH,
                            pose_index: r
                        });
                    }
                    // Right Column: Pose 0..rows-1 (Kembar)
                    for (let r = 0; r < rows; r++) {
                        newSlots.push({
                            id: 'slot_R' + (r + 1),
                            x: rightX,
                            y: topPad + r * (slotH + gapY),
                            w: colW,
                            h: slotH,
                            pose_index: r
                        });
                    }
                } else if (presetKey === 'grid_4') {
                    const colW = Math.round(w * 0.43);
                    const slotH = Math.round(h * 0.40);
                    const leftX = Math.round(w * 0.05);
                    const rightX = Math.round(w * 0.52);
                    const topY = Math.round(h * 0.06);
                    const botY = Math.round(h * 0.52);

                    newSlots.push({ id: 'slot_1', x: leftX, y: topY, w: colW, h: slotH, pose_index: 0 });
                    newSlots.push({ id: 'slot_2', x: rightX, y: topY, w: colW, h: slotH, pose_index: 1 });
                    newSlots.push({ id: 'slot_3', x: leftX, y: botY, w: colW, h: slotH, pose_index: 2 });
                    newSlots.push({ id: 'slot_4', x: rightX, y: botY, w: colW, h: slotH, pose_index: 3 });
                }

                this.slots = newSlots;
                this.selectedIndex = 0;
                if (shouldSync) {
                    this.onStateChange();
                }
            },

            addSlot(aspect = 'portrait') {
                const count = this.slots.length;
                const w = this.canvasW;
                const h = this.canvasH;
                const slotW = Math.round(w * 0.40);
                let slotH = Math.round(slotW * (4 / 3)); // 3:4 portrait
                if (aspect === 'square') slotH = slotW;
                if (aspect === 'landscape') slotH = Math.round(slotW * (3 / 4));

                const newSlot = {
                    id: 'slot_' + (count + 1) + '_' + Date.now(),
                    x: Math.round((w - slotW) / 2),
                    y: Math.min(h - slotH - 40, 60 + (count % 4) * 60),
                    w: slotW,
                    h: slotH,
                    pose_index: Math.min(7, count)
                };

                this.slots.push(newSlot);
                this.selectedIndex = this.slots.length - 1;
                this.onStateChange();
            },

            duplicateSlot(index) {
                if (index < 0 || index >= this.slots.length) return;
                const orig = this.slots[index];
                const copy = {
                    id: 'slot_copy_' + Date.now(),
                    x: Math.min(this.canvasW - orig.w, orig.x + 30),
                    y: Math.min(this.canvasH - orig.h, orig.y + 30),
                    w: orig.w,
                    h: orig.h,
                    pose_index: orig.pose_index
                };
                this.slots.push(copy);
                this.selectedIndex = this.slots.length - 1;
                this.onStateChange();
            },

            deleteSlot(index) {
                if (index < 0 || index >= this.slots.length) return;
                this.slots.splice(index, 1);
                this.selectedIndex = Math.max(0, this.slots.length - 1);
                this.onStateChange();
            },

            clearAllSlots() {
                this.slots = [];
                this.selectedIndex = -1;
                this.onStateChange();
            },

            setAspect(index, aspect) {
                if (index < 0 || index >= this.slots.length) return;
                const slot = this.slots[index];
                if (aspect === 'square') {
                    slot.h = slot.w;
                } else if (aspect === 'landscape') {
                    slot.h = Math.round(slot.w * (3 / 4));
                } else {
                    slot.h = Math.round(slot.w * (4 / 3));
                }
                this.onStateChange();
            },

            centerHorizontally(index) {
                if (index < 0 || index >= this.slots.length) return;
                const slot = this.slots[index];
                slot.x = Math.round((this.canvasW - slot.w) / 2);
                this.onStateChange();
            },

            startDrag(index, event) {
                this.selectedIndex = index;
                this.isDragging = true;
                this.isResizing = false;
                this.dragStartMouseX = event.clientX;
                this.dragStartMouseY = event.clientY;
                this.dragStartSlot = { ...this.slots[index] };
            },

            startTouchDrag(index, event) {
                if (event.touches.length > 0) {
                    this.selectedIndex = index;
                    this.isDragging = true;
                    this.isResizing = false;
                    this.dragStartMouseX = event.touches[0].clientX;
                    this.dragStartMouseY = event.touches[0].clientY;
                    this.dragStartSlot = { ...this.slots[index] };
                }
            },

            startResize(index, handle, event) {
                this.selectedIndex = index;
                this.isDragging = false;
                this.isResizing = true;
                this.resizeHandle = handle;
                this.dragStartMouseX = event.clientX;
                this.dragStartMouseY = event.clientY;
                this.dragStartSlot = { ...this.slots[index] };
            },

            startTouchResize(index, handle, event) {
                if (event.touches.length > 0) {
                    this.selectedIndex = index;
                    this.isDragging = false;
                    this.isResizing = true;
                    this.resizeHandle = handle;
                    this.dragStartMouseX = event.touches[0].clientX;
                    this.dragStartMouseY = event.touches[0].clientY;
                    this.dragStartSlot = { ...this.slots[index] };
                }
            },

            onPointerMove(event) {
                this.handleMove(event.clientX, event.clientY);
            },

            onTouchMove(event) {
                if (event.touches.length > 0) {
                    this.handleMove(event.touches[0].clientX, event.touches[0].clientY);
                }
            },

            handleMove(clientX, clientY) {
                if (!this.isDragging && !this.isResizing) return;
                if (this.selectedIndex < 0 || this.selectedIndex >= this.slots.length) return;

                const scale = this.displayW / this.canvasW;
                const deltaX = (clientX - this.dragStartMouseX) / scale;
                const deltaY = (clientY - this.dragStartMouseY) / scale;
                const slot = this.slots[this.selectedIndex];
                const start = this.dragStartSlot;

                if (this.isDragging) {
                    const newX = Math.round(start.x + deltaX);
                    const newY = Math.round(start.y + deltaY);
                    slot.x = Math.max(0, Math.min(this.canvasW - slot.w, newX));
                    slot.y = Math.max(0, Math.min(this.canvasH - slot.h, newY));
                } else if (this.isResizing) {
                    const minSize = 30;
                    if (this.resizeHandle === 'se') {
                        slot.w = Math.max(minSize, Math.min(this.canvasW - start.x, Math.round(start.w + deltaX)));
                        slot.h = Math.max(minSize, Math.min(this.canvasH - start.y, Math.round(start.h + deltaY)));
                    } else if (this.resizeHandle === 'sw') {
                        const newW = Math.max(minSize, Math.round(start.w - deltaX));
                        const newX = start.x + (start.w - newW);
                        if (newX >= 0) {
                            slot.w = newW;
                            slot.x = newX;
                        }
                        slot.h = Math.max(minSize, Math.min(this.canvasH - start.y, Math.round(start.h + deltaY)));
                    } else if (this.resizeHandle === 'ne') {
                        slot.w = Math.max(minSize, Math.min(this.canvasW - start.x, Math.round(start.w + deltaX)));
                        const newH = Math.max(minSize, Math.round(start.h - deltaY));
                        const newY = start.y + (start.h - newH);
                        if (newY >= 0) {
                            slot.h = newH;
                            slot.y = newY;
                        }
                    } else if (this.resizeHandle === 'nw') {
                        const newW = Math.max(minSize, Math.round(start.w - deltaX));
                        const newX = start.x + (start.w - newW);
                        const newH = Math.max(minSize, Math.round(start.h - deltaY));
                        const newY = start.y + (start.h - newH);
                        if (newX >= 0 && newY >= 0) {
                            slot.w = newW;
                            slot.x = newX;
                            slot.h = newH;
                            slot.y = newY;
                        }
                    }
                }
            },

            onPointerUp(event) {
                if (this.isDragging || this.isResizing) {
                    this.isDragging = false;
                    this.isResizing = false;
                    this.resizeHandle = null;
                    this.onStateChange();
                }
            },

            onStateChange() {
                const outputSlots = this.slots.map((s, idx) => ({
                    x: Math.round(Number(s.x)),
                    y: Math.round(Number(s.y)),
                    w: Math.round(Number(s.w)),
                    h: Math.round(Number(s.h)),
                    pose_index: Number(s.pose_index ?? idx)
                }));

                const poseCount = this.calculatedPoseCount;
                const layoutConfig = {
                    layout_type: outputSlots.length <= 4 ? 'single' : 'grid',
                    slot_count: outputSlots.length,
                    pose_count: poseCount,
                    slots: outputSlots,
                    dimensions: {
                        w: this.canvasW,
                        h: this.canvasH
                    }
                };

                this.state = layoutConfig;
            }
        };
    }
</script>
