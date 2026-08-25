<x-dynamic-component
    :component="$getFieldWrapperView()"
    :field="$field"
>
    @php
        $statePath = $getStatePath();
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
        class="border border-gray-300 dark:border-gray-700 rounded-xl p-4 bg-gray-50 dark:bg-gray-900/50 space-y-4"
    >
        <!-- Top Controls: Presets & Actions -->
        <div class="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 dark:border-gray-700 pb-3">
            <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Preset Cepat:</span>
                <button
                    type="button"
                    @click="applyPreset('strip_3')"
                    class="px-2.5 py-1 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 shadow-sm transition"
                >
                    🎞️ Strip 3 Foto
                </button>
                <button
                    type="button"
                    @click="applyPreset('strip_4')"
                    class="px-2.5 py-1 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 shadow-sm transition"
                >
                    🎞️ Strip 4 Foto
                </button>
                <button
                    type="button"
                    @click="applyPreset('twin_6')"
                    class="px-2.5 py-1 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 shadow-sm transition"
                >
                    👯 Kembar 6 Foto (2 Kolom)
                </button>
                <button
                    type="button"
                    @click="applyPreset('twin_8')"
                    class="px-2.5 py-1 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 shadow-sm transition"
                >
                    👯 Kembar 8 Foto (2 Kolom)
                </button>
                <button
                    type="button"
                    @click="applyPreset('grid_4')"
                    class="px-2.5 py-1 text-xs font-medium rounded-lg bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 shadow-sm transition"
                >
                    🔲 Grid 4 (2x2)
                </button>
            </div>

            <div class="flex items-center gap-2">
                <button
                    type="button"
                    @click="addSlot('portrait')"
                    class="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-semibold rounded-lg bg-primary-600 text-white hover:bg-primary-500 shadow-sm transition"
                >
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/></svg>
                    Tambah Kotak
                </button>
                <button
                    type="button"
                    @click="clearAllSlots()"
                    class="px-2.5 py-1.5 text-xs font-medium rounded-lg text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/30 transition"
                >
                    Reset Kanvas
                </button>
            </div>
        </div>

        <!-- Main Workspace: Canvas + Inspector -->
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            <!-- Left: Interactive Canvas (7 cols) -->
            <div class="lg:col-span-7 flex flex-col items-center">
                <div class="text-xs text-gray-500 dark:text-gray-400 mb-2 flex items-center justify-between w-full max-w-[420px]">
                    <span class="font-medium">📐 Kanvas Interaktif:</span>
                    <span>Klik & drag kotak untuk memindahkan / resize</span>
                </div>

                <!-- Canvas Viewport -->
                <div
                    x-ref="canvasContainer"
                    class="relative border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg overflow-hidden select-none shadow-md"
                    :style="`width: ${displayW}px; height: ${displayH}px; background: repeating-conic-gradient(#e5e7eb 0% 25%, #ffffff 0% 50%) 50% / 16px 16px;`"
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
                        <div class="absolute inset-0 flex flex-col items-center justify-center text-gray-400 text-xs p-4 text-center">
                            <svg class="w-8 h-8 mb-1 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                            <span>Upload file frame di atas untuk melihat desain latar kanvas</span>
                        </div>
                    </template>

                    <!-- Slot Boxes -->
                    <template x-for="(slot, idx) in slots" :key="slot.id || idx">
                        <div
                            class="absolute cursor-move transition-shadow rounded-sm flex items-center justify-center"
                            :class="{
                                'border-2 border-primary-500 bg-primary-500/25 ring-2 ring-primary-400/50 shadow-lg z-20': selectedIndex === idx,
                                'border-2 border-dashed border-sky-600 bg-sky-500/20 hover:bg-sky-500/30 z-10': selectedIndex !== idx
                            }"
                            :style="`left: ${toDispX(slot.x)}px; top: ${toDispY(slot.y)}px; width: ${toDispW(slot.w)}px; height: ${toDispH(slot.h)}px;`"
                            @mousedown.stop="startDrag(idx, $event)"
                            @touchstart.stop="startTouchDrag(idx, $event)"
                            @click.stop="selectedIndex = idx"
                        >
                            <!-- Badge Label -->
                            <div class="bg-gray-900/85 text-white px-2 py-0.5 rounded text-[10px] font-bold tracking-wider shadow pointer-events-none flex items-center gap-1 backdrop-blur-xs">
                                <span x-text="`#${idx + 1}`" class="text-sky-300"></span>
                                <span>•</span>
                                <span x-text="`POSE ${slot.pose_index + 1}`" class="text-amber-300"></span>
                            </div>

                            <!-- Resize Handles (Only for selected box) -->
                            <template x-if="selectedIndex === idx">
                                <div class="absolute inset-0 pointer-events-auto">
                                    <!-- SE Handle (Bottom Right) -->
                                    <div
                                        class="absolute -right-1.5 -bottom-1.5 w-3.5 h-3.5 bg-primary-600 border-2 border-white rounded-full cursor-se-resize shadow hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'se', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'se', $event)"
                                    ></div>
                                    <!-- SW Handle (Bottom Left) -->
                                    <div
                                        class="absolute -left-1.5 -bottom-1.5 w-3.5 h-3.5 bg-primary-600 border-2 border-white rounded-full cursor-sw-resize shadow hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'sw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'sw', $event)"
                                    ></div>
                                    <!-- NE Handle (Top Right) -->
                                    <div
                                        class="absolute -right-1.5 -top-1.5 w-3.5 h-3.5 bg-primary-600 border-2 border-white rounded-full cursor-ne-resize shadow hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'ne', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'ne', $event)"
                                    ></div>
                                    <!-- NW Handle (Top Left) -->
                                    <div
                                        class="absolute -left-1.5 -top-1.5 w-3.5 h-3.5 bg-primary-600 border-2 border-white rounded-full cursor-nw-resize shadow hover:scale-125 transition-transform"
                                        @mousedown.stop="startResize(idx, 'nw', $event)"
                                        @touchstart.stop="startTouchResize(idx, 'nw', $event)"
                                    ></div>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>
            </div>

            <!-- Right: Slot Inspector & Fine Tuning (5 cols) -->
            <div class="lg:col-span-5 space-y-4">
                <!-- Status Summary -->
                <div class="bg-white dark:bg-gray-800 p-3.5 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm flex items-center justify-between">
                    <div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">Total Kotak Foto</div>
                        <div class="text-lg font-bold text-gray-800 dark:text-gray-100" x-text="`${slots.length} Kotak`"></div>
                    </div>
                    <div class="h-8 w-px bg-gray-200 dark:bg-gray-700"></div>
                    <div>
                        <div class="text-xs text-gray-500 dark:text-gray-400">Pose Kamera Dibutuhkan</div>
                        <div class="text-lg font-bold text-amber-600 dark:text-amber-400" x-text="`${calculatedPoseCount} Pose`"></div>
                    </div>
                </div>

                <!-- Inspector Card (Active Slot Details) -->
                <template x-if="selectedSlot">
                    <div class="bg-white dark:bg-gray-800 p-4 rounded-xl border border-primary-300 dark:border-primary-700 shadow-sm space-y-3">
                        <div class="flex items-center justify-between border-b border-gray-100 dark:border-gray-700 pb-2">
                            <span class="text-xs font-bold text-primary-600 dark:text-primary-400 uppercase tracking-wide" x-text="`Pengaturan Kotak #${selectedIndex + 1}`"></span>
                            <div class="flex items-center gap-1">
                                <button
                                    type="button"
                                    @click="duplicateSlot(selectedIndex)"
                                    class="text-xs px-2 py-0.5 font-medium rounded bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 transition"
                                >
                                    Duplikat
                                </button>
                                <button
                                    type="button"
                                    @click="deleteSlot(selectedIndex)"
                                    class="text-xs px-2 py-0.5 font-medium rounded bg-red-50 dark:bg-red-950/40 hover:bg-red-100 text-red-600 dark:text-red-400 transition"
                                >
                                    Hapus
                                </button>
                            </div>
                        </div>

                        <!-- Pose Number Assignment -->
                        <div>
                            <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                                📸 Nomor Pose Kamera untuk Kotak Ini:
                            </label>
                            <select
                                x-model.number="selectedSlot.pose_index"
                                @change="onStateChange()"
                                class="w-full text-xs rounded-lg border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-primary-500 focus:border-primary-500 py-1.5"
                            >
                                <template x-for="p in 8" :key="p">
                                    <option :value="p - 1" x-text="`Pose #${p} (Foto ke-${p})`"></option>
                                </template>
                            </select>
                            <p class="text-[10px] text-gray-500 mt-1">
                                Kotak dengan nomor pose yang sama akan menampilkan foto yang sama (misal strip kembar kiri-kanan).
                            </p>
                        </div>

                        <!-- Quick Shape Adjusters -->
                        <div>
                            <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                                📐 Bentuk / Aspek Rasio Kotak:
                            </label>
                            <div class="grid grid-cols-3 gap-1.5">
                                <button
                                    type="button"
                                    @click="setAspect(selectedIndex, 'portrait')"
                                    class="px-2 py-1 text-[11px] font-medium rounded border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    Potret (3:4)
                                </button>
                                <button
                                    type="button"
                                    @click="setAspect(selectedIndex, 'square')"
                                    class="px-2 py-1 text-[11px] font-medium rounded border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    Persegi (1:1)
                                </button>
                                <button
                                    type="button"
                                    @click="setAspect(selectedIndex, 'landscape')"
                                    class="px-2 py-1 text-[11px] font-medium rounded border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700"
                                >
                                    Lanskap (4:3)
                                </button>
                            </div>
                        </div>

                        <!-- Fine-tune Coordinates -->
                        <div class="grid grid-cols-2 gap-2 pt-1">
                            <div>
                                <label class="text-[10px] font-medium text-gray-500">Posisi X (px)</label>
                                <input
                                    type="number"
                                    x-model.number="selectedSlot.x"
                                    @input="onStateChange()"
                                    class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1"
                                />
                            </div>
                            <div>
                                <label class="text-[10px] font-medium text-gray-500">Posisi Y (px)</label>
                                <input
                                    type="number"
                                    x-model.number="selectedSlot.y"
                                    @input="onStateChange()"
                                    class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1"
                                />
                            </div>
                            <div>
                                <label class="text-[10px] font-medium text-gray-500">Lebar W (px)</label>
                                <input
                                    type="number"
                                    x-model.number="selectedSlot.w"
                                    @input="onStateChange()"
                                    class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1"
                                />
                            </div>
                            <div>
                                <label class="text-[10px] font-medium text-gray-500">Tinggi H (px)</label>
                                <input
                                    type="number"
                                    x-model.number="selectedSlot.h"
                                    @input="onStateChange()"
                                    class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 py-1"
                                />
                            </div>
                        </div>

                        <!-- Alignment Quick Actions -->
                        <div class="flex items-center gap-2 pt-1">
                            <button
                                type="button"
                                @click="centerHorizontally(selectedIndex)"
                                class="w-full px-2 py-1 text-[11px] font-medium rounded bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 transition"
                            >
                                🎯 Ratakan Tengah (Center X)
                            </button>
                        </div>
                    </div>
                </template>

                <template x-if="!selectedSlot">
                    <div class="bg-white dark:bg-gray-800 p-6 rounded-xl border border-dashed border-gray-300 dark:border-gray-700 text-center text-xs text-gray-500 space-y-2">
                        <svg class="w-8 h-8 mx-auto opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 15l-2 5L9 9l11 4-5 2zm0 0l5 5M7.188 2.239l.777 2.897M5.136 7.965l-2.898-.777M13.95 4.05l-2.122 2.122m-5.657 5.656l-2.12 2.122"/></svg>
                        <p>Klik salah satu kotak di kanvas untuk mengubah nomor pose atau ukurannya secara mendalam.</p>
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

                        // Scale existing slots proportionally if canvas dimension changed
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

                fromDispX(val) {
                    return Math.round((val / this.displayW) * this.canvasW);
                },
                fromDispY(val) {
                    return Math.round((val / this.displayH) * this.canvasH);
                },

                // Preset Generator
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

                        // Left Column: Pose 1..rows
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
                        // Right Column: Kembar / Mirror
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
                        // Portrait 3:4
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

                // Pointer Drag & Resize Handling
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
</x-dynamic-component>
