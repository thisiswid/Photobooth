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

<div
    x-data="frameCanvasEditor({
        state: $wire.entangle('{{ $statePath }}'),
        initialConfig: @js($initialState),
        imageUrl: @js($initialImageUrl),
    })"
    x-init="initEditor()"
    class="w-full border border-gray-200 dark:border-gray-800 rounded-2xl p-5 bg-white dark:bg-gray-900 shadow-sm space-y-5"
>
    <!-- Top Header: Title & Quick Presets with Clean Line Icons -->
    <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4 border-b border-gray-100 dark:border-gray-800 pb-4">
        <div>
            <div class="flex items-center gap-2">
                <div class="p-1.5 rounded-lg bg-primary-50 dark:bg-primary-950/50 text-primary-600 dark:text-primary-400">
                    <!-- Device / Kiosk Outline Icon -->
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                        <rect x="5" y="2" width="14" height="20" rx="3" ry="3"></rect>
                        <line x1="12" y1="18" x2="12.01" y2="18" stroke-width="2.5" stroke-linecap="round"></line>
                    </svg>
                </div>
                <div>
                    <h3 class="text-sm font-bold text-gray-900 dark:text-gray-100">Visual Frame Builder & Pose Editor</h3>
                    <p class="text-xs text-gray-500 dark:text-gray-400">Atur letak kotak foto, bentuk, dan nomor pose kamera secara langsung di atas kanvas.</p>
                </div>
            </div>
        </div>

        <!-- Action Buttons with Outline Icons -->
        <div class="flex flex-wrap items-center gap-2">
            <button
                type="button"
                @click="addSlot('portrait')"
                class="inline-flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold rounded-xl bg-primary-600 text-white hover:bg-primary-500 shadow-sm transition"
            >
                <!-- Plus Outline Icon -->
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
                </svg>
                Tambah Kotak
            </button>
            <button
                type="button"
                @click="clearAllSlots()"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-xl text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/30 border border-red-200 dark:border-red-900/50 transition"
            >
                <!-- Trash Outline Icon -->
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                </svg>
                Reset Kanvas
            </button>
        </div>
    </div>

    <!-- Quick Preset Badges Toolbar -->
    <div class="flex flex-wrap items-center gap-2 bg-gray-50 dark:bg-gray-800/60 p-2.5 rounded-xl border border-gray-100 dark:border-gray-800">
        <span class="text-xs font-semibold text-gray-500 dark:text-gray-400 flex items-center gap-1.5 pl-1 pr-2">
            <!-- Layers Outline Icon -->
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"/>
            </svg>
            Preset Cepat:
        </span>
        <button
            type="button"
            @click="applyPreset('strip_3')"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 shadow-2xs transition"
        >
            <!-- Single Strip 3 Line Icon -->
            <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="7" y="2" width="10" height="20" rx="1"></rect>
                <line x1="7" y1="8" x2="17" y2="8"></line>
                <line x1="7" y1="14" x2="17" y2="14"></line>
            </svg>
            Strip 3 Foto
        </button>
        <button
            type="button"
            @click="applyPreset('strip_4')"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 shadow-2xs transition"
        >
            <!-- Single Strip 4 Line Icon -->
            <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
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
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 shadow-2xs transition"
        >
            <!-- Twin 6 Strip Line Icon -->
            <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
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
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 shadow-2xs transition"
        >
            <!-- Twin 8 Strip Line Icon -->
            <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
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
            class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 shadow-2xs transition"
        >
            <!-- Grid 4 Line Icon -->
            <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                <rect x="3" y="3" width="7" height="7" rx="1"></rect>
                <rect x="14" y="3" width="7" height="7" rx="1"></rect>
                <rect x="3" y="14" width="7" height="7" rx="1"></rect>
                <rect x="14" y="14" width="7" height="7" rx="1"></rect>
            </svg>
            Grid 4 (2x2)
        </button>
    </div>

    <!-- Main Editor Grid: Canvas Device Mockup on Left + Inspector Controls on Right -->
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        <!-- Left: Interactive Mobile / Kiosk Canvas Mockup (7 cols) -->
        <div class="lg:col-span-7 flex flex-col items-center">
            <!-- Mockup Outer Device Shell -->
            <div class="w-full max-w-[400px] bg-gray-900 dark:bg-black rounded-[36px] p-3.5 shadow-2xl border-4 border-gray-800 dark:border-gray-700 relative">
                <!-- Mobile Mockup Notch / Speaker Line -->
                <div class="w-24 h-4 bg-gray-800 dark:bg-gray-900 rounded-full mx-auto mb-2 flex items-center justify-center gap-1.5">
                    <div class="w-2.5 h-2.5 rounded-full bg-gray-700"></div>
                    <div class="w-10 h-1.5 rounded-full bg-gray-700"></div>
                </div>

                <!-- Canvas Viewport -->
                <div
                    x-ref="canvasContainer"
                    class="relative rounded-[22px] overflow-hidden select-none shadow-inner"
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
                            class="absolute inset-0 w-full h-full object-contain pointer-events-none"
                            alt="Background Frame"
                            @load="onImageLoaded($event)"
                        />
                    </template>

                    <template x-if="!imageUrl">
                        <div class="absolute inset-0 flex flex-col items-center justify-center text-gray-400 text-xs p-6 text-center">
                            <!-- Image Outline Icon -->
                            <svg class="w-10 h-10 mb-2 opacity-40 text-gray-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
                            </svg>
                            <span class="font-medium">File desain frame akan tampil di sini</span>
                            <span class="text-[11px] text-gray-400 mt-1">Upload desain pada kolom di atas</span>
                        </div>
                    </template>

                    <!-- Interactive Slot Boxes -->
                    <template x-for="(slot, idx) in slots" :key="slot.id || idx">
                        <div
                            class="absolute cursor-move transition-all rounded-lg flex items-center justify-center select-none"
                            :class="{
                                'border-2 border-primary-500 bg-primary-500/25 ring-2 ring-primary-400/60 shadow-xl z-20': selectedIndex === idx,
                                'border-2 border-dashed border-sky-500 bg-sky-500/15 hover:bg-sky-500/25 z-10': selectedIndex !== idx
                            }"
                            :style="`left: ${toDispX(slot.x)}px; top: ${toDispY(slot.y)}px; width: ${toDispW(slot.w)}px; height: ${toDispH(slot.h)}px;`"
                            @mousedown.stop="startDrag(idx, $event)"
                            @touchstart.stop="startTouchDrag(idx, $event)"
                            @click.stop="selectedIndex = idx"
                        >
                            <!-- Badge Label on Box with Camera Line Icon -->
                            <div class="bg-gray-950/85 text-white px-2.5 py-1 rounded-md text-[10px] font-bold tracking-wider shadow-md pointer-events-none flex items-center gap-1.5 backdrop-blur-xs border border-white/10">
                                <!-- Camera Outline Icon -->
                                <svg class="w-3 h-3 text-amber-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                                </svg>
                                <span x-text="`Kotak #${idx + 1}`" class="text-sky-300"></span>
                                <span class="text-gray-500">•</span>
                                <span x-text="`POSE ${slot.pose_index + 1}`" class="text-amber-300 font-extrabold"></span>
                            </div>

                            <!-- 4 Corner Resize Handles (Only for selected box) -->
                            <template x-if="selectedIndex === idx">
                                <div class="absolute inset-0 pointer-events-auto">
                                    <!-- SE (Bottom Right) -->
                                    <div
                                        class="absolute -right-2 -bottom-2 w-4 h-4 bg-primary-600 border-2 border-white rounded-full cursor-se-resize shadow-md hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'se', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'se', $event)"
                                    ></div>
                                    <!-- SW (Bottom Left) -->
                                    <div
                                        class="absolute -left-2 -bottom-2 w-4 h-4 bg-primary-600 border-2 border-white rounded-full cursor-sw-resize shadow-md hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'sw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'sw', $event)"
                                    ></div>
                                    <!-- NE (Top Right) -->
                                    <div
                                        class="absolute -right-2 -top-2 w-4 h-4 bg-primary-600 border-2 border-white rounded-full cursor-ne-resize shadow-md hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'ne', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'ne', $event)"
                                    ></div>
                                    <!-- NW (Top Left) -->
                                    <div
                                        class="absolute -left-2 -top-2 w-4 h-4 bg-primary-600 border-2 border-white rounded-full cursor-nw-resize shadow-md hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'nw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'nw', $event)"
                                    ></div>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>

                <!-- Bottom Home Bar Mockup -->
                <div class="w-28 h-1 bg-gray-700 rounded-full mx-auto mt-2.5 opacity-60"></div>
            </div>
        </div>

        <!-- Right: Slot Inspector & Controls (5 cols) -->
        <div class="lg:col-span-5 space-y-4">
            <!-- Status Card Summary -->
            <div class="grid grid-cols-2 gap-3 p-4 rounded-2xl bg-gray-50 dark:bg-gray-800/80 border border-gray-200 dark:border-gray-700">
                <div>
                    <div class="text-[11px] font-medium text-gray-500 dark:text-gray-400">Total Kotak Foto</div>
                    <div class="text-xl font-extrabold text-gray-900 dark:text-white" x-text="`${slots.length} Kotak`"></div>
                </div>
                <div>
                    <div class="text-[11px] font-medium text-gray-500 dark:text-gray-400">Pose Kamera Dibutuhkan</div>
                    <div class="text-xl font-extrabold text-amber-500 dark:text-amber-400" x-text="`${calculatedPoseCount} Pose`"></div>
                </div>
            </div>

            <!-- Active Slot Inspector Card -->
            <template x-if="selectedSlot">
                <div class="bg-white dark:bg-gray-800 p-5 rounded-2xl border-2 border-primary-500/40 dark:border-primary-500/30 shadow-lg space-y-4">
                    <div class="flex items-center justify-between border-b border-gray-100 dark:border-gray-700 pb-3">
                        <div class="flex items-center gap-2">
                            <span class="w-2.5 h-2.5 rounded-full bg-primary-500 animate-pulse"></span>
                            <span class="text-xs font-bold text-gray-900 dark:text-white uppercase tracking-wider" x-text="`Detail Kotak #${selectedIndex + 1}`"></span>
                        </div>
                        <div class="flex items-center gap-1.5">
                            <button
                                type="button"
                                @click="duplicateSlot(selectedIndex)"
                                class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-800 dark:text-gray-200 transition"
                            >
                                <!-- Copy Outline Icon -->
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625V10.875c0-.621.504-1.125 1.125-1.125h3.375m7.5 7.5H19.875c.621 0 1.125-.504 1.125-1.125V5.625c0-.621-.504-1.125-1.125-1.125H9.875c-.621 0-1.125.504-1.125 1.125v3.375m7.5 7.5h-7.5"/>
                                </svg>
                                Duplikat
                            </button>
                            <button
                                type="button"
                                @click="deleteSlot(selectedIndex)"
                                class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium rounded-lg bg-red-50 dark:bg-red-950/40 hover:bg-red-100 text-red-600 dark:text-red-400 transition"
                            >
                                <!-- Trash Outline Icon -->
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                                </svg>
                                Hapus
                            </button>
                        </div>
                    </div>

                    <!-- Pose Number Assignment -->
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 dark:text-gray-200 mb-1.5 flex items-center gap-1.5">
                            <!-- Camera Icon -->
                            <svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
                            </svg>
                            Nomor Pose Kamera untuk Kotak Ini:
                        </label>
                        <select
                            x-model.number="selectedSlot.pose_index"
                            @change="onStateChange()"
                            class="w-full text-xs font-semibold rounded-xl border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-2 focus:ring-primary-500 py-2 px-3"
                        >
                            <template x-for="p in 8" :key="p">
                                <option :value="p - 1" x-text="`Pose #${p} (Foto Jepretan ke-${p})`"></option>
                            </template>
                        </select>
                        <p class="text-[10px] text-gray-500 dark:text-gray-400 mt-1">
                            Kotak dengan nomor pose yang sama akan otomatis menampilkan foto jepretan yang sama (misal foto kembar kiri & kanan).
                        </p>
                    </div>

                    <!-- Shape Presets with Line Icons -->
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 dark:text-gray-200 mb-1.5">
                            Bentuk & Aspek Rasio:
                        </label>
                        <div class="grid grid-cols-3 gap-2">
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'portrait')"
                                class="flex flex-col items-center justify-center p-2 rounded-xl border border-gray-200 dark:border-gray-700 hover:border-primary-500 bg-gray-50 dark:bg-gray-700/50 hover:bg-primary-50 dark:hover:bg-primary-950/40 transition"
                            >
                                <svg class="w-5 h-5 text-gray-500 dark:text-gray-300 mb-1" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2"></rect></svg>
                                <span class="text-[10px] font-semibold">Potret (3:4)</span>
                            </button>
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'square')"
                                class="flex flex-col items-center justify-center p-2 rounded-xl border border-gray-200 dark:border-gray-700 hover:border-primary-500 bg-gray-50 dark:bg-gray-700/50 hover:bg-primary-50 dark:hover:bg-primary-950/40 transition"
                            >
                                <svg class="w-5 h-5 text-gray-500 dark:text-gray-300 mb-1" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"></rect></svg>
                                <span class="text-[10px] font-semibold">Persegi (1:1)</span>
                            </button>
                            <button
                                type="button"
                                @click="setAspect(selectedIndex, 'landscape')"
                                class="flex flex-col items-center justify-center p-2 rounded-xl border border-gray-200 dark:border-gray-700 hover:border-primary-500 bg-gray-50 dark:bg-gray-700/50 hover:bg-primary-50 dark:hover:bg-primary-950/40 transition"
                            >
                                <svg class="w-5 h-5 text-gray-500 dark:text-gray-300 mb-1" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24"><rect x="3" y="6" width="18" height="12" rx="2"></rect></svg>
                                <span class="text-[10px] font-semibold">Lanskap (4:3)</span>
                            </button>
                        </div>
                    </div>

                    <!-- Coordinate Inputs -->
                    <div class="grid grid-cols-2 gap-2.5 pt-1">
                        <div>
                            <label class="text-[10px] font-bold text-gray-500 dark:text-gray-400">Posisi X (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.x"
                                @input="onStateChange()"
                                class="w-full text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1.5 px-2.5"
                            />
                        </div>
                        <div>
                            <label class="text-[10px] font-bold text-gray-500 dark:text-gray-400">Posisi Y (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.y"
                                @input="onStateChange()"
                                class="w-full text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1.5 px-2.5"
                            />
                        </div>
                        <div>
                            <label class="text-[10px] font-bold text-gray-500 dark:text-gray-400">Lebar W (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.w"
                                @input="onStateChange()"
                                class="w-full text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1.5 px-2.5"
                            />
                        </div>
                        <div>
                            <label class="text-[10px] font-bold text-gray-500 dark:text-gray-400">Tinggi H (px)</label>
                            <input
                                type="number"
                                x-model.number="selectedSlot.h"
                                @input="onStateChange()"
                                class="w-full text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1.5 px-2.5"
                            />
                        </div>
                    </div>

                    <!-- Alignment Button -->
                    <button
                        type="button"
                        @click="centerHorizontally(selectedIndex)"
                        class="w-full inline-flex items-center justify-center gap-1.5 py-2 text-xs font-semibold rounded-xl bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-800 dark:text-gray-200 transition"
                    >
                        <!-- Center Align Icon -->
                        <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" stroke-width="1.75" viewBox="0 0 24 24">
                            <line x1="3" y1="6" x2="21" y2="6"></line>
                            <line x1="6" y1="12" x2="18" y2="12"></line>
                            <line x1="3" y1="18" x2="21" y2="18"></line>
                        </svg>
                        Ratakan Tengah Horizontal (Center X)
                    </button>
                </div>
            </template>

            <template x-if="!selectedSlot">
                <div class="bg-gray-50 dark:bg-gray-800/50 p-8 rounded-2xl border-2 border-dashed border-gray-200 dark:border-gray-700 text-center text-xs text-gray-500 space-y-2">
                    <svg class="w-10 h-10 mx-auto opacity-40 text-gray-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 8.608 3.978-2.94 1.134m-3.727 2.133L15.042 21.672zm-7.632-4.83a8.966 8.966 0 01-.84-2.842M3.93 11.02a8.966 8.966 0 011.05-3.324m2.132-2.825A8.966 8.966 0 0110.435 3.5"/>
                    </svg>
                    <p class="font-medium text-gray-600 dark:text-gray-300">Pilih salah satu kotak di kanvas</p>
                    <p class="text-[11px] text-gray-400">Klik kotak untuk mengatur nomor pose, mengubah bentuk, atau menggeser posisi koordinat.</p>
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
                    const minSize = 40;
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
