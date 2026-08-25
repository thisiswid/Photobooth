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
    .fbe-container { width: 100%; border: 1px solid #e2e8f0; border-radius: 18px; padding: 20px; background: #ffffff; box-sizing: border-box; font-family: inherit; }
    .dark .fbe-container { border-color: #1e293b; background: #0f172a; }
    .fbe-icon-sm { width: 14px !important; height: 14px !important; min-width: 14px !important; min-height: 14px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-icon-md { width: 18px !important; height: 18px !important; min-width: 18px !important; min-height: 18px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-icon-lg { width: 22px !important; height: 22px !important; min-width: 22px !important; min-height: 22px !important; display: inline-block !important; vertical-align: middle; flex-shrink: 0; }
    .fbe-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 6px 12px; font-size: 12px; font-weight: 600; border-radius: 8px; cursor: pointer; transition: all 0.15s ease; text-decoration: none; border: 1px solid transparent; }
    .fbe-preset-btn { background: #f8fafc; border-color: #e2e8f0; color: #334155; }
    .fbe-preset-btn:hover { background: #f1f5f9; border-color: #cbd5e1; color: #0f172a; }
    .dark .fbe-preset-btn { background: #1e293b; border-color: #334155; color: #cbd5e1; }
    .dark .fbe-preset-btn:hover { background: #334155; color: #ffffff; }
    .fbe-primary-btn { background: #2563eb; color: #ffffff; border: none; }
    .fbe-primary-btn:hover { background: #1d4ed8; }
    .fbe-danger-btn { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
    .fbe-danger-btn:hover { background: #fee2e2; }
    .dark .fbe-danger-btn { background: #450a0a; color: #f87171; border-color: #7f1d1d; }
    .fbe-studio-shell { width: 100%; max-width: 440px; background: #090d16; border-radius: 28px; padding: 14px; box-shadow: 0 25px 35px -5px rgba(0, 0, 0, 0.4); border: 3px solid #1e293b; margin: 0 auto; box-sizing: border-box; position: relative; }
    .fbe-canvas-viewport { position: relative; border-radius: 16px; overflow: hidden; user-select: none; box-shadow: inset 0 2px 4px 0 rgba(0, 0, 0, 0.1); margin: 0 auto; }
    .fbe-canvas-box { position: absolute; border-radius: 6px; display: flex; align-items: center; justify-content: center; user-select: none; cursor: move; box-sizing: border-box; }
    .fbe-badge { background: rgba(15, 23, 42, 0.92); color: #ffffff; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 800; display: inline-flex; align-items: center; gap: 5px; pointer-events: none; border: 1px solid rgba(255,255,255,0.2); box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3); letter-spacing: 0.5px; }
    .fbe-handle-corner { position: absolute; width: 16px; height: 16px; background: #2563eb; border: 2.5px solid #ffffff; border-radius: 9999px; box-shadow: 0 2px 5px rgba(0,0,0,0.4); z-index: 50; }
    .fbe-handle-corner:hover { transform: scale(1.35); background: #1d4ed8; }
    .fbe-handle-edge { position: absolute; background: #2563eb; border: 2px solid #ffffff; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.4); z-index: 50; }
    .fbe-handle-edge:hover { transform: scale(1.25); background: #1d4ed8; }
    .fbe-input { width: 100%; font-size: 12px; font-weight: 600; border-radius: 8px; border: 1px solid #cbd5e1; background: #f8fafc; padding: 7px 10px; box-sizing: border-box; color: #0f172a; }
    .dark .fbe-input { border-color: #475569; background: #1e293b; color: #f8fafc; }
</style>

<div
    x-data="frameCanvasEditor({
        state: $wire.entangle('{{ $statePath }}'),
        initialConfig: @js($initialState),
        imageUrl: @js($initialImageUrl),
    })"
    x-init="initEditor()"
    @mousemove.window="onPointerMove($event)"
    @mouseup.window="onPointerUp($event)"
    @touchmove.window="onTouchMove($event)"
    @touchend.window="onPointerUp($event)"
    class="fbe-container"
>
    <!-- Top Header: Title & Quick Presets with Clean Line Icons -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; border-bottom: 1px solid #e2e8f0; padding-bottom: 16px; margin-bottom: 16px;">
        <div style="display: flex; align-items: center; gap: 12px;">
            <div style="padding: 8px; border-radius: 10px; background: #eff6ff; color: #2563eb; display: flex; align-items: center; justify-content: center;">
                <!-- Frame / Canvas Studio Line Icon -->
                <svg class="fbe-icon-lg" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <rect x="3" y="3" width="18" height="18" rx="3"></rect>
                    <rect x="7" y="7" width="10" height="10" rx="1.5" stroke-dasharray="2 2"></rect>
                </svg>
            </div>
            <div>
                <div style="font-size: 14px; font-weight: 800; color: #0f172a;">Studio Desain Frame & Posisi Kotak Foto</div>
                <div style="font-size: 11px; color: #64748b;">Desain bingkai frame Anda tampil di bawah. Letakkan kotak pose tepat di atas area lubang foto.</div>
            </div>
        </div>

        <!-- Action Controls -->
        <div style="display: flex; align-items: center; gap: 8px;">
            <!-- Simulation Mode Toggle -->
            <button
                type="button"
                @click="showPhotoSimulation = !showPhotoSimulation"
                class="fbe-btn"
                :style="showPhotoSimulation ? 'background: #f0fdf4; color: #16a34a; border-color: #bbf7d0;' : 'background: #f8fafc; color: #475569; border-color: #e2e8f0;'"
            >
                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                </svg>
                <span x-text="showPhotoSimulation ? '✓ Simulasi Foto Nyala' : 'Simulasi Foto'"></span>
            </button>

            <button
                type="button"
                @click="addSlot('portrait')"
                class="fbe-btn fbe-primary-btn"
            >
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
                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                </svg>
                <span>Reset</span>
            </button>
        </div>
    </div>

    <!-- Quick Preset Buttons Toolbar -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 8px; background: #f8fafc; padding: 10px; border-radius: 12px; border: 1px solid #e2e8f0; margin-bottom: 20px;">
        <span style="font-size: 11px; font-weight: 700; color: #64748b; display: inline-flex; align-items: center; gap: 6px; padding: 0 4px;">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"/>
            </svg>
            Preset Template Cepat:
        </span>
        <button type="button" @click="applyPreset('strip_3')" class="fbe-btn fbe-preset-btn">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="7" y="2" width="10" height="20" rx="1"></rect><line x1="7" y1="8" x2="17" y2="8"></line><line x1="7" y1="14" x2="17" y2="14"></line></svg>
            Strip 3 Foto
        </button>
        <button type="button" @click="applyPreset('strip_4')" class="fbe-btn fbe-preset-btn">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="7" y="2" width="10" height="20" rx="1"></rect><line x1="7" y1="7" x2="17" y2="7"></line><line x1="7" y1="12" x2="17" y2="12"></line><line x1="7" y1="17" x2="17" y2="17"></line></svg>
            Strip 4 Foto
        </button>
        <button type="button" @click="applyPreset('twin_6')" class="fbe-btn fbe-preset-btn">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"></rect><line x1="12" y1="3" x2="12" y2="21"></line><line x1="3" y1="9" x2="21" y2="9"></line><line x1="3" y1="15" x2="21" y2="15"></line></svg>
            Kembar 6 Foto (2 Kolom)
        </button>
        <button type="button" @click="applyPreset('twin_8')" class="fbe-btn fbe-preset-btn">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="2" width="18" height="20" rx="2"></rect><line x1="12" y1="2" x2="12" y2="22"></line><line x1="3" y1="7" x2="21" y2="7"></line><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="17" x2="21" y2="17"></line></svg>
            Kembar 8 Foto (2 Kolom)
        </button>
        <button type="button" @click="applyPreset('grid_4')" class="fbe-btn fbe-preset-btn">
            <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"></rect><rect x="14" y="3" width="7" height="7" rx="1"></rect><rect x="3" y="14" width="7" height="7" rx="1"></rect><rect x="14" y="14" width="7" height="7" rx="1"></rect></svg>
            Grid 4 (2x2)
        </button>
    </div>

    <!-- Main Workspace: Large Frame Studio Viewport + Inspector Controls -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 28px; align-items: start;">
        <!-- Left: Studio Visual Canvas -->
        <div style="display: flex; flex-direction: column; align-items: center;">
            <div class="fbe-studio-shell">
                <!-- Top Status Header -->
                <div style="display: flex; align-items: center; justify-content: space-between; color: #94a3b8; font-size: 10px; font-weight: 700; margin-bottom: 10px; padding: 0 4px;">
                    <span style="display: flex; align-items: center; gap: 6px;">
                        <span style="width: 6px; height: 6px; border-radius: 9999px; background: #22c55e;"></span>
                        KANVAS FRAME STUDIO
                    </span>
                    <span x-text="`${canvasW} × ${canvasH} px`"></span>
                </div>

                <!-- Canvas Viewport -->
                <div
                    x-ref="canvasContainer"
                    class="fbe-canvas-viewport"
                    :style="`width: ${displayW}px; height: ${displayH}px; background: repeating-conic-gradient(#cbd5e1 0% 25%, #ffffff 0% 50%) 50% / 20px 20px;`"
                >
                    <!-- Background: Uploaded Frame Design -->
                    <template x-if="imageUrl">
                        <img
                            :src="imageUrl"
                            style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; pointer-events: none; z-index: 1;"
                            alt="Background Frame Design"
                            @load="onImageLoaded($event)"
                        />
                    </template>

                    <!-- Empty State Guide -->
                    <template x-if="!imageUrl">
                        <div style="position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #64748b; font-size: 12px; padding: 24px; text-align: center; z-index: 1;">
                            <svg class="fbe-icon-lg" style="width: 32px; height: 32px; margin-bottom: 10px; opacity: 0.5; color: #94a3b8;" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
                            </svg>
                            <span style="font-weight: 700; color: #334155;">Pilih / Upload Gambar Frame di Atas</span>
                            <span style="font-size: 10px; color: #94a3b8; margin-top: 4px;">Desain frame Anda akan langsung tampil nyata di sini!</span>
                        </div>
                    </template>

                    <!-- Draggable / Resizable Pose Boxes Overlay -->
                    <template x-for="(slot, idx) in slots" :key="slot.id || idx">
                        <div
                            class="fbe-canvas-box"
                            :style="`left: ${toDispX(slot.x)}px; top: ${toDispY(slot.y)}px; width: ${toDispW(slot.w)}px; height: ${toDispH(slot.h)}px; ${
                                selectedIndex === idx
                                    ? 'border: 3px solid #2563eb; background: rgba(37, 99, 235, 0.35); box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.45); z-index: 30;'
                                    : 'border: 2px dashed #0284c7; background: rgba(14, 165, 233, 0.22); z-index: 10;'
                            }`"
                            @mousedown.stop="startDrag(idx, $event)"
                            @touchstart.stop="startTouchDrag(idx, $event)"
                            @click.stop="selectedIndex = idx"
                        >
                            <!-- Photo Simulation Overlay (if enabled) -->
                            <template x-if="showPhotoSimulation">
                                <div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: #e2e8f0; pointer-events: none; overflow: hidden;">
                                    <img
                                        :src="getSamplePhotoUrl(slot.pose_index)"
                                        style="width: 100%; height: 100%; object-fit: cover; opacity: 0.85;"
                                        alt="Simulasi Foto"
                                    />
                                </div>
                            </template>

                            <!-- Badge Label with Camera Icon -->
                            <div class="fbe-badge" style="z-index: 40;">
                                <svg class="fbe-icon-sm" style="color: #fbbf24;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                                </svg>
                                <span x-text="`Kotak #${idx + 1}`" style="color: #7dd3fc;"></span>
                                <span style="color: #64748b;">•</span>
                                <span x-text="`POSE ${slot.pose_index + 1}`" style="color: #fde047; font-weight: 900;"></span>
                            </div>

                            <!-- 8 Resize Handles (Active only on selected box) -->
                            <template x-if="selectedIndex === idx">
                                <div style="position: absolute; inset: 0; pointer-events: auto;">
                                    <!-- 4 Corners -->
                                    <div class="fbe-handle-corner" style="right: -8px; bottom: -8px; cursor: nwse-resize;" @mousedown.stop.prevent="startResize(idx, 'se', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'se', $event)"></div>
                                    <div class="fbe-handle-corner" style="left: -8px; bottom: -8px; cursor: nesw-resize;" @mousedown.stop.prevent="startResize(idx, 'sw', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'sw', $event)"></div>
                                    <div class="fbe-handle-corner" style="right: -8px; top: -8px; cursor: nesw-resize;" @mousedown.stop.prevent="startResize(idx, 'ne', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'ne', $event)"></div>
                                    <div class="fbe-handle-corner" style="left: -8px; top: -8px; cursor: nwse-resize;" @mousedown.stop.prevent="startResize(idx, 'nw', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'nw', $event)"></div>

                                    <!-- 4 Edges -->
                                    <div class="fbe-handle-edge" style="right: -6px; top: 50%; transform: translateY(-50%); width: 8px; height: 22px; cursor: ew-resize;" @mousedown.stop.prevent="startResize(idx, 'e', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'e', $event)"></div>
                                    <div class="fbe-handle-edge" style="left: -6px; top: 50%; transform: translateY(-50%); width: 8px; height: 22px; cursor: ew-resize;" @mousedown.stop.prevent="startResize(idx, 'w', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'w', $event)"></div>
                                    <div class="fbe-handle-edge" style="bottom: -6px; left: 50%; transform: translateX(-50%); width: 22px; height: 8px; cursor: ns-resize;" @mousedown.stop.prevent="startResize(idx, 's', $event)" @touchstart.stop.prevent="startTouchResize(idx, 's', $event)"></div>
                                    <div class="fbe-handle-edge" style="top: -6px; left: 50%; transform: translateX(-50%); width: 22px; height: 8px; cursor: ns-resize;" @mousedown.stop.prevent="startResize(idx, 'n', $event)" @touchstart.stop.prevent="startTouchResize(idx, 'n', $event)"></div>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>

                <!-- Footer Hint -->
                <div style="font-size: 10px; text-align: center; color: #64748b; margin-top: 12px; font-weight: 500;">
                    💡 Tips: Geser kotak ke atas lubang foto pada frame, lalu sesuaikan ukurannya.
                </div>
            </div>
        </div>

        <!-- Right: Inspector Controls & Coordinate Settings -->
        <div style="display: flex; flex-direction: column; gap: 16px;">
            <!-- Summary Stats Card -->
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 14px; border-radius: 14px; background: #f8fafc; border: 1px solid #e2e8f0;">
                <div>
                    <div style="font-size: 11px; font-weight: 700; color: #64748b;">Jumlah Kotak Foto</div>
                    <div style="font-size: 20px; font-weight: 900; color: #0f172a;" x-text="`${slots.length} Kotak`"></div>
                </div>
                <div>
                    <div style="font-size: 11px; font-weight: 700; color: #64748b;">Pose Kamera Dibutuhkan</div>
                    <div style="font-size: 20px; font-weight: 900; color: #d97706;" x-text="`${calculatedPoseCount} Pose`"></div>
                </div>
            </div>

            <!-- Active Slot Detail Card -->
            <template x-if="selectedSlot">
                <div style="padding: 18px; border-radius: 16px; background: #ffffff; border: 2px solid #93c5fd; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); display: flex; flex-direction: column; gap: 14px;">
                    <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #f1f5f9; padding-bottom: 10px;">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span style="width: 10px; height: 10px; border-radius: 9999px; background: #2563eb;"></span>
                            <span style="font-size: 13px; font-weight: 800; color: #1e3a8a; text-transform: uppercase;" x-text="`Pengaturan Kotak #${selectedIndex + 1}`"></span>
                        </div>
                        <div style="display: flex; align-items: center; gap: 6px;">
                            <button type="button" @click="duplicateSlot(selectedIndex)" class="fbe-btn fbe-preset-btn" style="padding: 4px 8px; font-size: 11px;">
                                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625V10.875c0-.621.504-1.125 1.125-1.125h3.375m7.5 7.5H19.875c.621 0 1.125-.504 1.125-1.125V5.625c0-.621-.504-1.125-1.125-1.125H9.875c-.621 0-1.125.504-1.125 1.125v3.375m7.5 7.5h-7.5"/></svg>
                                <span>Duplikat</span>
                            </button>
                            <button type="button" @click="deleteSlot(selectedIndex)" class="fbe-btn fbe-danger-btn" style="padding: 4px 8px; font-size: 11px;">
                                <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                                <span>Hapus</span>
                            </button>
                        </div>
                    </div>

                    <!-- Pose Assignment -->
                    <div>
                        <label style="display: flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 700; color: #1e293b; margin-bottom: 6px;">
                            <svg class="fbe-icon-sm" style="color: #d97706;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                            </svg>
                            Foto Kamera yang Masuk ke Kotak Ini:
                        </label>
                        <select
                            x-model.number="selectedSlot.pose_index"
                            @change="onStateChange()"
                            class="fbe-input"
                            style="font-size: 13px; font-weight: 700;"
                        >
                            <template x-for="p in 8" :key="p">
                                <option :value="p - 1" x-text="`Pose #${p} (Hasil Jepretan Kamera ke-${p})`"></option>
                            </template>
                        </select>
                        <div style="font-size: 10px; color: #64748b; margin-top: 4px;">
                            Jika ada 2 kotak dengan Pose #1, maka kedua kotak tersebut akan menampilkan foto jepretan yang sama (kembar).
                        </div>
                    </div>

                    <!-- Shape Presets -->
                    <div>
                        <label style="display: block; font-size: 11px; font-weight: 700; color: #1e293b; margin-bottom: 6px;">
                            Bentuk & Aspek Rasio Kotak:
                        </label>
                        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;">
                            <button type="button" @click="setAspect(selectedIndex, 'portrait')" class="fbe-btn fbe-preset-btn" style="flex-direction: column; padding: 8px 4px; gap: 4px;">
                                <svg class="fbe-icon-md" style="color: #64748b;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Potret (3:4)</span>
                            </button>
                            <button type="button" @click="setAspect(selectedIndex, 'square')" class="fbe-btn fbe-preset-btn" style="flex-direction: column; padding: 8px 4px; gap: 4px;">
                                <svg class="fbe-icon-md" style="color: #64748b;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Persegi (1:1)</span>
                            </button>
                            <button type="button" @click="setAspect(selectedIndex, 'landscape')" class="fbe-btn fbe-preset-btn" style="flex-direction: column; padding: 8px 4px; gap: 4px;">
                                <svg class="fbe-icon-md" style="color: #64748b;" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="12" rx="2"></rect></svg>
                                <span style="font-size: 10px;">Lanskap (4:3)</span>
                            </button>
                        </div>
                    </div>

                    <!-- Pixel Numeric Coordinates -->
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #64748b;">Posisi X (px)</label>
                            <input type="number" x-model.number="selectedSlot.x" @input="onStateChange()" class="fbe-input"/>
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #64748b;">Posisi Y (px)</label>
                            <input type="number" x-model.number="selectedSlot.y" @input="onStateChange()" class="fbe-input"/>
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #64748b;">Lebar W (px)</label>
                            <input type="number" x-model.number="selectedSlot.w" @input="onStateChange()" class="fbe-input"/>
                        </div>
                        <div>
                            <label style="font-size: 10px; font-weight: 700; color: #64748b;">Tinggi H (px)</label>
                            <input type="number" x-model.number="selectedSlot.h" @input="onStateChange()" class="fbe-input"/>
                        </div>
                    </div>

                    <!-- Alignment Button -->
                    <button type="button" @click="centerHorizontally(selectedIndex)" class="fbe-btn fbe-preset-btn" style="width: 100%; padding: 8px;">
                        <svg class="fbe-icon-sm" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                            <line x1="3" y1="6" x2="21" y2="6"></line>
                            <line x1="6" y1="12" x2="18" y2="12"></line>
                            <line x1="3" y1="18" x2="21" y2="18"></line>
                        </svg>
                        <span>Ratakan Tengah Horizontal (Center X)</span>
                    </button>
                </div>
            </template>

            <template x-if="!selectedSlot">
                <div style="padding: 28px; border-radius: 16px; background: #f8fafc; border: 2px dashed #cbd5e1; text-align: center; color: #64748b; font-size: 12px;">
                    <svg class="fbe-icon-lg" style="margin: 0 auto 8px auto; opacity: 0.4;" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 8.608 3.978-2.94 1.134m-3.727 2.133L15.042 21.672zm-7.632-4.83a8.966 8.966 0 01-.84-2.842M3.93 11.02a8.966 8.966 0 011.05-3.324m2.132-2.825A8.966 8.966 0 0110.435 3.5"/>
                    </svg>
                    <div style="font-weight: 700; color: #334155;">Pilih salah satu kotak di kanvas</div>
                    <div style="font-size: 11px; color: #94a3b8; margin-top: 4px;">Klik kotak foto untuk mengatur nomor pose kamera atau mengubah ukurannya.</div>
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
            displayW: 320,
            displayH: 960,
            slots: [],
            selectedIndex: 0,
            showPhotoSimulation: false,
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
                    this.applyPreset('strip_4', false);
                }

                if (this.slots.length > 0) {
                    this.selectedIndex = 0;
                }

                // Listen to dynamic file upload changes from browser directly (Instant preview)
                this.$nextTick(() => {
                    const fileInputs = document.querySelectorAll('input[type="file"]');
                    fileInputs.forEach(input => {
                        input.addEventListener('change', (e) => {
                            if (e.target.files && e.target.files[0]) {
                                const file = e.target.files[0];
                                const blobUrl = URL.createObjectURL(file);
                                this.imageUrl = blobUrl;
                                
                                const tempImg = new Image();
                                tempImg.onload = () => {
                                    this.canvasW = tempImg.naturalWidth;
                                    this.canvasH = tempImg.naturalHeight;
                                    this.updateDisplayDimensions();
                                    this.onStateChange();
                                };
                                tempImg.src = blobUrl;
                            }
                        });
                    });
                });

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

            getSamplePhotoUrl(poseIndex) {
                const samples = [
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
                    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=80',
                    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500&auto=format&fit=crop&q=80',
                ];
                return samples[poseIndex % samples.length];
            },

            updateDisplayDimensions() {
                const maxW = 340;
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
                let slotH = Math.round(slotW * (4 / 3));
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
                    const minSize = 25;
                    const h = this.resizeHandle;

                    if (h === 'se') {
                        slot.w = Math.max(minSize, Math.min(this.canvasW - start.x, Math.round(start.w + deltaX)));
                        slot.h = Math.max(minSize, Math.min(this.canvasH - start.y, Math.round(start.h + deltaY)));
                    } else if (h === 'sw') {
                        const newW = Math.max(minSize, Math.round(start.w - deltaX));
                        const newX = start.x + (start.w - newW);
                        if (newX >= 0) {
                            slot.w = newW;
                            slot.x = newX;
                        }
                        slot.h = Math.max(minSize, Math.min(this.canvasH - start.y, Math.round(start.h + deltaY)));
                    } else if (h === 'ne') {
                        slot.w = Math.max(minSize, Math.min(this.canvasW - start.x, Math.round(start.w + deltaX)));
                        const newH = Math.max(minSize, Math.round(start.h - deltaY));
                        const newY = start.y + (start.h - newH);
                        if (newY >= 0) {
                            slot.h = newH;
                            slot.y = newY;
                        }
                    } else if (h === 'nw') {
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
                    } else if (h === 'e') {
                        slot.w = Math.max(minSize, Math.min(this.canvasW - start.x, Math.round(start.w + deltaX)));
                    } else if (h === 's') {
                        slot.h = Math.max(minSize, Math.min(this.canvasH - start.y, Math.round(start.h + deltaY)));
                    } else if (h === 'w') {
                        const newW = Math.max(minSize, Math.round(start.w - deltaX));
                        const newX = start.x + (start.w - newW);
                        if (newX >= 0) {
                            slot.w = newW;
                            slot.x = newX;
                        }
                    } else if (h === 'n') {
                        const newH = Math.max(minSize, Math.round(start.h - deltaY));
                        const newY = start.y + (start.h - newH);
                        if (newY >= 0) {
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
