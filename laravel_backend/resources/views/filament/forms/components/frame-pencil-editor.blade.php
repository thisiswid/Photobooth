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
            if (str_starts_with($imageVal, 'http://') || str_starts_with($imageVal, 'https://') || str_starts_with($imageVal, 'blob:')) {
                $initialImageUrl = $imageVal;
            } else {
                $initialImageUrl = '/storage/' . ltrim($imageVal, '/');
            }
        }
    }
@endphp

<style>
    .fpe-container { width: 100%; border: 1px solid #e2e8f0; border-radius: 18px; padding: 20px; background: #ffffff; box-sizing: border-box; font-family: inherit; }
    .dark .fpe-container { border-color: #1e293b; background: #0f172a; }
    .fpe-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 7px 14px; font-size: 12px; font-weight: 700; border-radius: 10px; cursor: pointer; transition: all 0.15s ease; border: 1px solid transparent; text-decoration: none; user-select: none; }
    .fpe-btn-active { background: #2563eb; color: #ffffff; border-color: #1d4ed8; box-shadow: 0 2px 4px rgba(37,99,235,0.3); }
    .fpe-btn-normal { background: #f8fafc; color: #334155; border-color: #cbd5e1; }
    .fpe-btn-normal:hover { background: #f1f5f9; color: #0f172a; border-color: #94a3b8; }
    .dark .fpe-btn-normal { background: #1e293b; color: #cbd5e1; border-color: #334155; }
    .dark .fpe-btn-normal:hover { background: #334155; color: #ffffff; }
    .fpe-btn-green { background: #dcfce7; color: #15803d; border-color: #86efac; }
    .fpe-btn-green:hover { background: #bbf7d0; color: #166534; }
    .fpe-canvas-wrapper { position: relative; max-width: 100%; min-width: 280px; min-height: 400px; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.25); border: 3px solid #334155; background: repeating-conic-gradient(#cbd5e1 0% 25%, #ffffff 0% 50%) 50% / 18px 18px; margin: 0 auto; display: inline-flex; align-items: center; justify-content: center; }
    .fpe-canvas-box { position: absolute; border: 2px dashed #3b82f6; background: transparent; border-radius: 6px; pointer-events: none; display: flex; align-items: flex-start; justify-content: flex-start; padding: 6px; box-sizing: border-box; }
    .fpe-badge { background: rgba(15, 23, 42, 0.88); color: #ffffff; padding: 4px 8px; border-radius: 6px; font-size: 10px; font-weight: 800; display: inline-flex; align-items: center; gap: 4px; border: 1px solid rgba(255,255,255,0.25); box-shadow: 0 4px 6px rgba(0,0,0,0.3); backdrop-filter: blur(4px); }
    .fpe-loupe { position: absolute; pointer-events: none; width: 34px; height: 34px; border-radius: 9999px; border: 2.5px solid #ffffff; box-shadow: 0 4px 10px rgba(0,0,0,0.5); transform: translate(-50%, -50%); z-index: 60; }
    .fpe-upload-placeholder { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px 20px; text-align: center; color: #475569; cursor: pointer; }
</style>

<div
    x-data="framePencilEditor({
        state: $wire.entangle('{{ $statePath }}'),
        initialConfig: @js($initialState),
        imageUrl: @js($initialImageUrl),
    })"
    x-init="initEditor()"
    class="fpe-container"
>
    <!-- Top Toolbar: Pencil Mode, Quick Green Punch, Reset, Tolerance -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; border-bottom: 1px solid #e2e8f0; padding-bottom: 16px; margin-bottom: 18px;">
        <div style="display: flex; align-items: center; gap: 10px;">
            <div style="padding: 8px; border-radius: 10px; background: #eff6ff; color: #2563eb; display: flex; align-items: center; justify-content: center;">
                <svg style="width: 22px; height: 22px;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0l2.77-2.77m-2.77 2.77l-1.5 1.5m6.77-6.77l2.77-2.77a2.25 2.25 0 000-3.182l-1.364-1.364a2.25 2.25 0 00-3.182 0l-2.77 2.77m4.546 4.546l-4.546-4.546m0 0L3.75 14.25v3.75h3.75l9.25-9.25z"/>
                </svg>
            </div>
            <div>
                <div style="font-size: 14px; font-weight: 800; color: #0f172a;">Alat Pensil & Kanvas Melubangi Frame</div>
                <div style="font-size: 11px; color: #64748b;">Klik langsung pada kotak warna di gambar frame untuk melubanginya jadi transparan secara instan.</div>
            </div>
        </div>

        <!-- Action Tools -->
        <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 8px;">
            <!-- Active Tool: Pencil Mode -->
            <button
                type="button"
                @click="isPencilActive = true"
                class="fpe-btn"
                :class="isPencilActive ? 'fpe-btn-active' : 'fpe-btn-normal'"
            >
                <svg style="width: 15px; height: 15px;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125"/>
                </svg>
                <span>✏️ Alat Pensil / Klik Warna</span>
            </button>

            <!-- Quick Auto-Green Punch -->
            <button
                type="button"
                @click="punchChromaGreen()"
                class="fpe-btn fpe-btn-green"
                title="Otomatis melubangi semua warna hijau terang (#00FF00) dalam 1 klik"
            >
                <span style="width: 10px; height: 10px; border-radius: 9999px; background: #22c55e; display: inline-block;"></span>
                <span>🟢 Lubangi Hijau Otomatis</span>
            </button>

            <!-- Reset Button -->
            <button
                type="button"
                @click="resetOriginalImage()"
                class="fpe-btn fpe-btn-normal"
                title="Kembalikan gambar ke kondisi asli sebelum dilubangi"
            >
                <svg style="width: 14px; height: 14px;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"/>
                </svg>
                <span>Kembali Asli</span>
            </button>
        </div>
    </div>

    <!-- Live Status & Tolerance Bar -->
    <div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; background: #f8fafc; padding: 10px 14px; border-radius: 12px; border: 1px solid #e2e8f0; margin-bottom: 20px;">
        <!-- Detected Slots Info -->
        <div style="display: flex; align-items: center; gap: 16px;">
            <div>
                <span style="font-size: 11px; font-weight: 700; color: #64748b;">Lubang Foto: </span>
                <span style="font-size: 13px; font-weight: 900; color: #2563eb;" x-text="`${slots.length} Lubang Terdeteksi`"></span>
            </div>
            <div>
                <span style="font-size: 11px; font-weight: 700; color: #64748b;">Ukuran Desain: </span>
                <span style="font-size: 12px; font-weight: 800; color: #0f172a;" x-text="hasImageLoaded ? `${canvasW} × ${canvasH} px` : 'Menunggu upload...'"></span>
            </div>
        </div>

        <!-- Color Tolerance Slider -->
        <div style="display: flex; align-items: center; gap: 8px;">
            <label style="font-size: 11px; font-weight: 700; color: #64748b;">Sensitivitas Warna:</label>
            <input
                type="range"
                min="15"
                max="90"
                x-model.number="tolerance"
                style="cursor: pointer; width: 100px;"
            />
            <span style="font-size: 11px; font-weight: 800; color: #0f172a;" x-text="tolerance"></span>
        </div>
    </div>

    <!-- Main Visual Canvas Workspace -->
    <div style="text-align: center;">
        <div
            class="fpe-canvas-wrapper"
            @dragover.prevent
            @drop.prevent="handleDrop($event)"
        >
            <!-- HTML5 Interactive Canvas (visible when image loaded) -->
            <canvas
                x-show="hasImageLoaded"
                x-ref="frameCanvas"
                @mousemove="onCanvasMouseMove($event)"
                @mouseleave="onCanvasMouseLeave()"
                @click="onCanvasClick($event)"
                :style="`cursor: crosshair; width: ${displayW}px; height: ${displayH}px; display: block;`"
            ></canvas>

            <!-- Placeholder if image is not loaded yet -->
            <div
                x-show="!hasImageLoaded"
                @click="$refs.localFileInput.click()"
                class="fpe-upload-placeholder"
            >
                <svg style="width: 42px; height: 42px; color: #94a3b8; margin-bottom: 12px;" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
                </svg>
                <div style="font-size: 13px; font-weight: 700; color: #1e293b;">Pilih / Upload File Desain Frame</div>
                <div style="font-size: 11px; color: #64748b; margin-top: 4px;">Pilih file pada upload di atas atau klik kotak ini</div>
            </div>

            <!-- Hidden direct file input as fallback -->
            <input
                type="file"
                x-ref="localFileInput"
                @change="onLocalFileChosen($event)"
                accept="image/png,image/jpeg,image/webp"
                style="display: none;"
            />

            <!-- Hover Loupe Circle (shows sampled color) -->
            <template x-if="hoverColor && hasImageLoaded">
                <div
                    class="fpe-loupe"
                    :style="`left: ${hoverDispX}px; top: ${hoverDispY}px; background: ${hoverColor};`"
                ></div>
            </template>

            <!-- Detected Hole Badges Overlay -->
            <template x-if="hasImageLoaded">
                <template x-for="(slot, idx) in slots" :key="idx">
                    <div
                        class="fpe-canvas-box"
                        :style="`left: ${toDispX(slot.x)}px; top: ${toDispY(slot.y)}px; width: ${toDispW(slot.w)}px; height: ${toDispH(slot.h)}px;`"
                    >
                        <div class="fpe-badge">
                            <svg style="width: 12px; height: 12px; color: #fbbf24;" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z"/>
                            </svg>
                            <span x-text="`Foto #${idx + 1}`" style="color: #7dd3fc;"></span>
                            <span style="color: #64748b;">•</span>
                            <span x-text="`Pose ${slot.pose_index + 1}`" style="color: #fde047; font-weight: 900;"></span>
                        </div>
                    </div>
                </template>
            </template>
        </div>

        <div style="font-size: 11px; color: #64748b; margin-top: 12px; font-weight: 500;">
            💡 <strong>Petunjuk:</strong> Arahkan pensil ke kotak warna (misal hijau) pada gambar di atas, lalu <strong>klik</strong> untuk melubanginya menjadi transparan.
        </div>
    </div>
</div>

<script>
    function framePencilEditor(params) {
        return {
            state: params.state,
            imageUrl: params.imageUrl,
            canvasW: 600,
            canvasH: 1800,
            displayW: 340,
            displayH: 1020,
            slots: [],
            hasImageLoaded: false,
            isPencilActive: true,
            tolerance: 45,
            hoverColor: null,
            hoverDispX: 0,
            hoverDispY: 0,
            originalImageObj: null,

            initEditor() {
                const cfg = params.initialConfig || {};
                if (cfg.dimensions) {
                    this.canvasW = cfg.dimensions.w || 600;
                    this.canvasH = cfg.dimensions.h || 1800;
                }
                if (Array.isArray(cfg.slots)) {
                    this.slots = cfg.slots;
                }
                this.updateDisplayDimensions();

                this.$nextTick(() => {
                    if (this.imageUrl) {
                        this.loadImage(this.imageUrl);
                    }

                    // 1. Delegated change listener on document (captures all file inputs)
                    document.addEventListener('change', (e) => {
                        if (e.target && e.target.type === 'file' && e.target.files && e.target.files[0]) {
                            const file = e.target.files[0];
                            const blobUrl = URL.createObjectURL(file);
                            this.imageUrl = blobUrl;
                            this.loadImage(blobUrl);
                        }
                    }, true);

                    // 2. FilePond global event listener
                    window.addEventListener('FilePond:addfile', (e) => {
                        if (e.detail && e.detail.file && e.detail.file.file) {
                            const blobUrl = URL.createObjectURL(e.detail.file.file);
                            this.imageUrl = blobUrl;
                            this.loadImage(blobUrl);
                        }
                    });

                    // 3. Watch for Livewire / FilePond DOM image preview injection
                    const observer = new MutationObserver(() => {
                        const filepondImg = document.querySelector('.filepond--image-preview-wrapper img, .filepond--item-preview img');
                        if (filepondImg && filepondImg.src && filepondImg.src !== this.imageUrl && filepondImg.src.startsWith('blob:')) {
                            this.imageUrl = filepondImg.src;
                            this.loadImage(filepondImg.src);
                        }
                    });
                    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });
                });
            },

            onLocalFileChosen(event) {
                if (event.target.files && event.target.files[0]) {
                    const file = event.target.files[0];
                    const blobUrl = URL.createObjectURL(file);
                    this.imageUrl = blobUrl;
                    this.loadImage(blobUrl);
                }
            },

            handleDrop(event) {
                if (event.dataTransfer && event.dataTransfer.files && event.dataTransfer.files[0]) {
                    const file = event.dataTransfer.files[0];
                    const blobUrl = URL.createObjectURL(file);
                    this.imageUrl = blobUrl;
                    this.loadImage(blobUrl);
                }
            },

            updateDisplayDimensions() {
                const maxW = 340;
                const ratio = this.canvasW / Math.max(1, this.canvasH);
                this.displayW = maxW;
                this.displayH = Math.round(maxW / ratio);
            },

            toDispX(val) { return Math.round((val / this.canvasW) * this.displayW); },
            toDispY(val) { return Math.round((val / this.canvasH) * this.displayH); },
            toDispW(val) { return Math.round((val / this.canvasW) * this.displayW); },
            toDispH(val) { return Math.round((val / this.canvasH) * this.displayH); },

            loadImage(src) {
                if (!src) return;
                const img = new Image();
                img.crossOrigin = 'anonymous';
                img.onload = () => {
                    this.originalImageObj = img;
                    this.canvasW = img.naturalWidth;
                    this.canvasH = img.naturalHeight;
                    this.hasImageLoaded = true;
                    this.updateDisplayDimensions();

                    this.$nextTick(() => {
                        const canvas = this.$refs.frameCanvas;
                        if (canvas) {
                            canvas.width = this.canvasW;
                            canvas.height = this.canvasH;
                            const ctx = canvas.getContext('2d');
                            ctx.clearRect(0, 0, this.canvasW, this.canvasH);
                            ctx.drawImage(img, 0, 0);

                            // Detect transparent holes if image is already a transparent PNG
                            this.detectHolesFromCanvas();
                        }
                    });
                };
                img.src = src;
            },

            onCanvasMouseMove(event) {
                const canvas = this.$refs.frameCanvas;
                if (!canvas) return;
                const rect = canvas.getBoundingClientRect();
                const mouseX = event.clientX - rect.left;
                const mouseY = event.clientY - rect.top;

                this.hoverDispX = mouseX;
                this.hoverDispY = mouseY;

                const imgX = Math.floor((mouseX / this.displayW) * this.canvasW);
                const imgY = Math.floor((mouseY / this.displayH) * this.canvasH);

                const ctx = canvas.getContext('2d');
                if (imgX >= 0 && imgX < this.canvasW && imgY >= 0 && imgY < this.canvasH) {
                    const pixel = ctx.getImageData(imgX, imgY, 1, 1).data;
                    this.hoverColor = `rgb(${pixel[0]}, ${pixel[1]}, ${pixel[2]})`;
                }
            },

            onCanvasMouseLeave() {
                this.hoverColor = null;
            },

            onCanvasClick(event) {
                if (!this.isPencilActive) return;
                const canvas = this.$refs.frameCanvas;
                if (!canvas) return;
                const rect = canvas.getBoundingClientRect();
                const mouseX = event.clientX - rect.left;
                const mouseY = event.clientY - rect.top;

                const imgX = Math.floor((mouseX / this.displayW) * this.canvasW);
                const imgY = Math.floor((mouseY / this.displayH) * this.canvasH);

                const ctx = canvas.getContext('2d');
                const clickedPixel = ctx.getImageData(imgX, imgY, 1, 1).data;
                const targetR = clickedPixel[0];
                const targetG = clickedPixel[1];
                const targetB = clickedPixel[2];

                this.punchColor(targetR, targetG, targetB);
            },

            punchChromaGreen() {
                this.punchColor(0, 255, 0, true);
            },

            punchColor(tr, tg, tb, isChromaMode = false) {
                const canvas = this.$refs.frameCanvas;
                if (!canvas) return;
                const ctx = canvas.getContext('2d');
                const imgData = ctx.getImageData(0, 0, this.canvasW, this.canvasH);
                const data = imgData.data;
                const tol = this.tolerance;

                for (let i = 0; i < data.length; i += 4) {
                    const r = data[i];
                    const g = data[i + 1];
                    const b = data[i + 2];
                    const a = data[i + 3];

                    if (a === 0) continue;

                    let shouldErase = false;
                    if (isChromaMode) {
                        if (g > 110 && g > (r + 30) && g > (b + 30)) {
                            shouldErase = true;
                        } else {
                            const dist = Math.sqrt(r * r + (255 - g) * (255 - g) + b * b);
                            if (dist < 135) shouldErase = true;
                        }
                    } else {
                        const dist = Math.sqrt((r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2);
                        if (dist <= tol) {
                            shouldErase = true;
                        }
                    }

                    if (shouldErase) {
                        data[i + 3] = 0; // Alpha 0 = 100% transparent
                    }
                }

                ctx.putImageData(imgData, 0, 0);
                this.detectHolesFromCanvas();
            },

            resetOriginalImage() {
                if (this.originalImageObj) {
                    const canvas = this.$refs.frameCanvas;
                    if (canvas) {
                        const ctx = canvas.getContext('2d');
                        ctx.clearRect(0, 0, this.canvasW, this.canvasH);
                        ctx.drawImage(this.originalImageObj, 0, 0);
                        this.detectHolesFromCanvas();
                    }
                }
            },

            detectHolesFromCanvas() {
                const canvas = this.$refs.frameCanvas;
                if (!canvas) return;
                const ctx = canvas.getContext('2d');
                const imgData = ctx.getImageData(0, 0, this.canvasW, this.canvasH);
                const data = imgData.data;
                const w = this.canvasW;
                const h = this.canvasH;
                const step = 8;
                const transparentSamples = [];

                for (let y = 0; y < h; y += step) {
                    for (let x = 0; x < w; x += step) {
                        const idx = (y * w + x) * 4;
                        const a = data[idx + 3];
                        if (a < 64) {
                            transparentSamples.push({ x, y });
                        }
                    }
                }

                if (transparentSamples.length === 0) {
                    this.slots = [];
                    this.onStateChange();
                    return;
                }

                const midX = w / 2;
                const centerSamples = transparentSamples.filter(p => Math.abs(p['x'] - midX) <= (w * 0.05));
                const isSingleCol = centerSamples.length >= 10;

                const clusterPoints = (samples) => {
                    if (samples.length === 0) return [];
                    const yMap = {};
                    samples.forEach(p => { yMap[p.y] = true; });
                    const yVals = Object.keys(yMap).map(Number).sort((a, b) => a - b);

                    const clusters = [];
                    let cur = [];
                    let prev = null;
                    yVals.forEach(y => {
                        if (prev === null || (y - prev) <= 24) {
                            cur.push(y);
                        } else {
                            if (cur.length >= 8) clusters.push(cur);
                            cur = [y];
                        }
                        prev = y;
                    });
                    if (cur.length >= 8) clusters.push(cur);

                    const foundSlots = [];
                    clusters.forEach(c => {
                        const minY = Math.min(...c);
                        const maxY = Math.max(...c);
                        const slotH = maxY - minY;
                        if (slotH < (h * 0.06)) return;

                        const rowPts = samples.filter(p => p.y >= minY && p.y <= maxY);
                        if (rowPts.length === 0) return;
                        const xVals = rowPts.map(p => p.x);
                        const minX = Math.min(...xVals);
                        const maxX = Math.max(...xVals);
                        const slotW = maxX - minX;
                        if (slotW < (w * 0.15)) return;

                        foundSlots.push({ x: minX, y: minY, w: slotW, h: slotH });
                    });
                    return foundSlots;
                };

                let detected = [];
                if (isSingleCol) {
                    detected = clusterPoints(transparentSamples);
                    detected.forEach((s, idx) => { s.pose_index = idx; });
                } else {
                    const leftPts = transparentSamples.filter(p => p.x < midX);
                    const rightPts = transparentSamples.filter(p => p.x >= midX);
                    const leftSlots = clusterPoints(leftPts);
                    const rightSlots = clusterPoints(rightPts);
                    leftSlots.forEach((s, idx) => { s.pose_index = idx; });
                    rightSlots.forEach((s, idx) => { s.pose_index = idx; });
                    detected = [...leftSlots, ...rightSlots];
                }

                this.slots = detected;
                this.onStateChange();
            },

            onStateChange() {
                const poseCount = this.slots.length > 0 ? Math.max(...this.slots.map(s => s.pose_index + 1)) : 4;
                const layoutConfig = {
                    layout_type: this.slots.length <= 4 ? 'single' : 'grid',
                    slot_count: this.slots.length,
                    pose_count: poseCount,
                    slots: this.slots,
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
