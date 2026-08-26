<!DOCTYPE html>
<html lang="id" class="scroll-smooth">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SnapTechBooth — Solusi Photobooth Digital untuk Cafe & Event</title>
    <meta name="description" content="Sistem operasi photobooth all-in-one: Kiosk Android, auto-print 300 DPI, download QR instan, dan integrasi QRIS otomatis untuk cafe dan event.">
    
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['"Plus Jakarta Sans"', 'sans-serif'],
                    },
                    colors: {
                        brand: {
                            50: '#eff6ff',
                            100: '#dbeafe',
                            500: '#3b82f6',
                            600: '#2563eb',
                            700: '#1d4ed8',
                            900: '#1e3a8a',
                        },
                        dark: {
                            950: '#070b14',
                            900: '#0c1222',
                            850: '#11192e',
                            800: '#18233c',
                            700: '#263554',
                        }
                    }
                }
            }
        }
    </script>

    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: #070b14;
            color: #f1f5f9;
        }
        .glow-grid {
            background-size: 40px 40px;
            background-image: 
                linear-gradient(to right, rgba(255, 255, 255, 0.03) 1px, transparent 1px),
                linear-gradient(to bottom, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
        }
        .radial-glow {
            background: radial-gradient(circle at 50% 0%, rgba(37, 99, 235, 0.18), transparent 70%);
        }
    </style>
</head>
<body class="antialiased selection:bg-brand-600 selection:text-white">

    <!-- Ambient Glow Background -->
    <div class="fixed inset-0 glow-grid pointer-events-none z-0"></div>
    <div class="fixed top-0 left-1/2 -translate-x-1/2 w-full max-w-7xl h-[600px] radial-glow pointer-events-none z-0"></div>

    <!-- Navigation Header -->
    <header class="sticky top-0 z-50 backdrop-blur-md bg-dark-950/80 border-b border-white/5">
        <div class="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
            <!-- Brand Logo -->
            <a href="/" class="flex items-center gap-3 group">
                <div class="w-10 h-10 rounded-xl bg-brand-600/10 border border-brand-500/30 flex items-center justify-center text-brand-500 group-hover:bg-brand-600 group-hover:text-white transition duration-300">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z"/>
                    </svg>
                </div>
                <div class="flex flex-col">
                    <span class="text-lg font-extrabold tracking-tight text-white">SnapTech<span class="text-brand-500">Booth</span></span>
                    <span class="text-[10px] text-slate-400 font-medium -mt-1 tracking-wider uppercase">Photobooth System</span>
                </div>
            </a>

            <!-- Nav Links -->
            <nav class="hidden md:flex items-center gap-8 text-sm font-medium text-slate-300">
                <a href="#fitur" class="hover:text-white transition">Fitur</a>
                <a href="#cara-kerja" class="hover:text-white transition">Cara Kerja</a>
                <a href="#harga" class="hover:text-white transition">Paket & Harga</a>
                <a href="#faq" class="hover:text-white transition">FAQ</a>
            </nav>

            <!-- Actions -->
            <div class="flex items-center gap-4">
                <a href="/admin" class="text-sm font-semibold text-slate-300 hover:text-white transition px-4 py-2">
                    Masuk Dashboard
                </a>
                <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20tertarik%20dengan%20layanan%20photobooth%20untuk%20bisnis%20saya" target="_blank" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-sm font-semibold shadow-lg shadow-brand-600/20 transition duration-200">
                    <span>Mulai Sekarang</span>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                    </svg>
                </a>
            </div>
        </div>
    </header>

    <!-- Hero Section -->
    <section class="relative pt-24 pb-20 z-10 overflow-hidden">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-3xl mx-auto text-center">
                <!-- Chip Badge -->
                <div class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-semibold text-brand-400 mb-8 backdrop-blur-sm">
                    <span class="w-2 h-2 rounded-full bg-brand-500 animate-pulse"></span>
                    Sistem Operasi Photobooth Digital Modern
                </div>

                <!-- Main Headline -->
                <h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-[1.15] mb-6">
                    Solusi Photobooth Digital untuk <span class="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 via-brand-500 to-indigo-400">Cafe & Event Anda</span>
                </h1>

                <!-- Subheadline -->
                <p class="text-base sm:text-lg text-slate-400 leading-relaxed mb-10 max-w-2xl mx-auto font-normal">
                    Tingkatkan pengalaman pengunjung dan ciptakan sumber pendapatan baru dengan sistem photobooth mandiri: Kiosk Android responsif, cetak instan, download QR tanpa aplikasi, dan integrasi pembayaran QRIS otomatis.
                </p>

                <!-- CTA Buttons -->
                <div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
                    <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20ingin%20konsultasi%20paket%20photobooth" target="_blank" class="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-7 py-3.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-sm shadow-xl shadow-brand-600/30 transition duration-200">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"/>
                        </svg>
                        <span>Konsultasi & Demo Gratis</span>
                    </a>
                    <a href="#harga" class="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-7 py-3.5 rounded-xl bg-dark-850 hover:bg-dark-800 text-slate-200 border border-white/10 font-semibold text-sm transition duration-200">
                        <span>Lihat Pilihan Paket</span>
                        <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                        </svg>
                    </a>
                </div>
            </div>

            <!-- Visual Showcase Mockup -->
            <div class="relative max-w-5xl mx-auto mt-4">
                <div class="rounded-2xl border border-white/10 bg-dark-900/90 p-4 sm:p-6 shadow-2xl shadow-black/80 backdrop-blur-xl">
                    <!-- Terminal/Bar Header -->
                    <div class="flex items-center justify-between border-b border-white/5 pb-4 mb-6">
                        <div class="flex items-center gap-2">
                            <div class="w-3 h-3 rounded-full bg-red-500/80"></div>
                            <div class="w-3 h-3 rounded-full bg-yellow-500/80"></div>
                            <div class="w-3 h-3 rounded-full bg-emerald-500/80"></div>
                        </div>
                        <div class="text-xs text-slate-400 font-mono flex items-center gap-2">
                            <svg class="w-3.5 h-3.5 text-brand-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            Kiosk Android Mode • Cloud Real-Time Active
                        </div>
                        <div class="text-xs text-slate-500 font-medium hidden sm:block">SnapTech Kiosk v2.4</div>
                    </div>

                    <!-- Interface Preview Grid -->
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 items-center">
                        <!-- Column 1: Kiosk Capture Flow -->
                        <div class="bg-dark-950/80 border border-white/5 rounded-xl p-5 flex flex-col justify-between h-80">
                            <div>
                                <div class="flex items-center gap-2 text-xs font-semibold text-brand-400 uppercase tracking-wider mb-2">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                                    </svg>
                                    01. Interaksi Kiosk
                                </div>
                                <h3 class="text-sm font-bold text-white mb-2">Live Countdown & Retake</h3>
                                <p class="text-xs text-slate-400 leading-relaxed">Pengunjung memilih layout frame, pose foto dengan aba-aba suara, dan opsi retake langsung di layar.</p>
                            </div>
                            <div class="p-3 bg-dark-850 rounded-lg border border-white/5 flex items-center justify-between text-xs">
                                <span class="text-slate-300 font-medium">Auto-Shutter Camera</span>
                                <span class="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 font-bold text-[10px]">Ready</span>
                            </div>
                        </div>

                        <!-- Column 2: Photo Strip & Multi-Asset Output -->
                        <div class="bg-gradient-to-b from-dark-850 to-dark-950 border border-brand-500/20 rounded-xl p-5 flex flex-col justify-between h-80 relative overflow-hidden">
                            <div class="absolute top-0 right-0 w-32 h-32 bg-brand-500/10 rounded-full blur-2xl pointer-events-none"></div>
                            <div>
                                <div class="flex items-center gap-2 text-xs font-semibold text-emerald-400 uppercase tracking-wider mb-2">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24-1.656-.613-3.195-1.12-4.577m0 0a15.82 15.82 0 016.4-1.252c1.786 0 3.498.286 5.093.816m-11.493.436C6.72 9.08 7.5 7.6 7.5 6a7.5 7.5 0 0115 0c0 1.6-.78 3.08-2.107 4.252"/>
                                    </svg>
                                    02. Output Generasi
                                </div>
                                <h3 class="text-sm font-bold text-white mb-2">Photo Strip, GIF & Video</h3>
                                <p class="text-xs text-slate-400 leading-relaxed">Sekali sesi menghasilkan 3 aset sekaligus: File cetak 300 DPI, motion GIF, dan live video MP4.</p>
                            </div>
                            <div class="space-y-2">
                                <div class="flex items-center justify-between text-xs px-3 py-2 bg-dark-900 rounded-lg border border-white/5">
                                    <span class="text-slate-300">Photo Strip HD (Print Ready)</span>
                                    <span class="text-brand-400 font-mono text-[11px]">300 DPI</span>
                                </div>
                                <div class="flex items-center justify-between text-xs px-3 py-2 bg-dark-900 rounded-lg border border-white/5">
                                    <span class="text-slate-300">Animated Looping GIF</span>
                                    <span class="text-emerald-400 font-mono text-[11px]">HD Auto</span>
                                </div>
                            </div>
                        </div>

                        <!-- Column 3: Direct QR Download & Analytics -->
                        <div class="bg-dark-950/80 border border-white/5 rounded-xl p-5 flex flex-col justify-between h-80">
                            <div>
                                <div class="flex items-center gap-2 text-xs font-semibold text-indigo-400 uppercase tracking-wider mb-2">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0113.5 9.375v-4.5z"/>
                                    </svg>
                                    03. Unduh & Analitik
                                </div>
                                <h3 class="text-sm font-bold text-white mb-2">Scan QR Langsung ke HP</h3>
                                <p class="text-xs text-slate-400 leading-relaxed">Tamu scan QR di layar untuk simpan ke smartphone. Semua metrik transaksi tersinkron ke dashboard Anda.</p>
                            </div>
                            <div class="p-3 bg-dark-850 rounded-lg border border-white/5 flex items-center justify-between text-xs">
                                <span class="text-slate-300 font-medium">Cloud Web Portal</span>
                                <span class="px-2 py-0.5 rounded bg-brand-500/10 text-brand-400 font-bold text-[10px]">Instant</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Core Features Grid -->
    <section id="fitur" class="py-24 z-10 relative border-t border-white/5 bg-dark-900/40">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-2xl mx-auto text-center mb-16">
                <h2 class="text-xs font-bold tracking-widest text-brand-400 uppercase mb-3">Fitur Lengkap</h2>
                <p class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Semua yang Anda Butuhkan untuk Menjalankan Photobooth</p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                <!-- Feature 1: Plug & Play Android Kiosk -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-brand-500/10 border border-brand-500/20 flex items-center justify-center text-brand-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Aplikasi Kiosk Android Ringan</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Kompatibel dengan tablet Android, Smart Display, dan Mini PC. Antarmuka full-screen yang ramah pengguna tanpa gangguan navigasi sistem.</p>
                    </div>
                </div>

                <!-- Feature 2: Interactive Frame Canvas & Green Eraser -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0l2.77-2.77m-2.77 2.77l-1.5 1.5m6.77-6.77l2.77-2.77a2.25 2.25 0 000-3.182l-1.364-1.364a2.25 2.25 0 00-3.182 0l-2.77 2.77m4.546 4.546l-4.546-4.546m0 0L3.75 14.25v3.75h3.75l9.25-9.25z"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Alat Pensil & Green Eraser</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Kelola frame kustom dengan mudah. Upload desain PNG atau gunakan alat pensil sekali klik untuk melubangi kotak warna penanda foto menjadi transparan.</p>
                    </div>
                </div>

                <!-- Feature 3: Seamless Auto-Printing -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24-1.656-.613-3.195-1.12-4.577m0 0a15.82 15.82 0 016.4-1.252c1.786 0 3.498.286 5.093.816m-11.493.436C6.72 9.08 7.5 7.6 7.5 6a7.5 7.5 0 0115 0c0 1.6-.78 3.08-2.107 4.252"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Layanan Cetak Otomatis (Auto-Print)</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Mendukung printer foto dye-sublimation dan inkjet standar. Begitu sesi selesai, foto langsung terpotong rapi dan dicetak otomatis tanpa tombol konfirmasi tambahan.</p>
                    </div>
                </div>

                <!-- Feature 4: QRIS Self-Payment -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Integrasi Pembayaran QRIS</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Pengunjung dapat membayar mandiri menggunakan aplikasi e-wallet / m-banking apa saja. Pembayaran terverifikasi otomatis dalam detik.</p>
                    </div>
                </div>

                <!-- Feature 5: Multi-Tenant Cloud Dashboard -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-sky-500/10 border border-sky-500/20 flex items-center justify-center text-sky-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Dashboard Finansial & Operasional</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Pantau grafik omset harian, jumlah sesi per jam, log aktivitas, dan kesehatan perangkat booth dari laptop atau smartphone Anda secara realtime.</p>
                    </div>
                </div>

                <!-- Feature 6: Filter & Color Aesthetics -->
                <div class="p-8 rounded-2xl bg-dark-850/60 border border-white/5 hover:border-brand-500/30 transition duration-300 flex flex-col justify-between">
                    <div>
                        <div class="w-12 h-12 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400 mb-6">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M4.098 19.902a3.75 3.75 0 005.304 0l6.401-6.402M6.75 21A3.75 3.75 0 013 17.25V4.125C3 3.504 3.504 3 4.125 3h5.25c.621 0 1.125.504 1.125 1.125v4.072M6.75 21a3.75 3.75 0 003.75-3.75V8.197M6.75 21h13.125c.621 0 1.125-.504 1.125-1.125v-5.25c0-.621-.504-1.125-1.125-1.125h-4.072M10.5 8.197l9.402 9.402"/>
                            </svg>
                        </div>
                        <h3 class="text-lg font-bold text-white mb-2">Preset Filter Warna Estetik</h3>
                        <p class="text-sm text-slate-400 leading-relaxed">Tersedia ragam filter populer seperti BW Noir, Warm Vintage, Soft Pastel, hingga Cyber Glow untuk hasil foto yang selalu siap dibagikan ke media sosial.</p>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- How It Works Flow -->
    <section id="cara-kerja" class="py-24 z-10 relative border-t border-white/5">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-2xl mx-auto text-center mb-16">
                <h2 class="text-xs font-bold tracking-widest text-brand-400 uppercase mb-3">Alur Operasional</h2>
                <p class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Pengalaman Sederhana & Cepat untuk Pelanggan</p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div class="p-6 rounded-xl bg-dark-900/60 border border-white/5">
                    <span class="text-xs font-mono font-bold text-brand-400">LANGKAH 01</span>
                    <h3 class="text-base font-bold text-white mt-2 mb-2">Pilih Frame & Bayar</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Pengunjung memilih desain frame dan menyelesaikan pembayaran langsung via scan QRIS.</p>
                </div>
                <div class="p-6 rounded-xl bg-dark-900/60 border border-white/5">
                    <span class="text-xs font-mono font-bold text-emerald-400">LANGKAH 02</span>
                    <h3 class="text-base font-bold text-white mt-2 mb-2">Sesi Pemotretan</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Kamera mengambil pose foto secara berurutan dengan countdown visual dan audio panduan.</p>
                </div>
                <div class="p-6 rounded-xl bg-dark-900/60 border border-white/5">
                    <span class="text-xs font-mono font-bold text-indigo-400">LANGKAH 03</span>
                    <h3 class="text-base font-bold text-white mt-2 mb-2">Pilih Filter & Cetak</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Pengunjung memilih filter warna favorit. Mesin secara otomatis mencetak foto fisik.</p>
                </div>
                <div class="p-6 rounded-xl bg-dark-900/60 border border-white/5">
                    <span class="text-xs font-mono font-bold text-amber-400">LANGKAH 04</span>
                    <h3 class="text-base font-bold text-white mt-2 mb-2">Scan QR Download</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">QR Code muncul di layar untuk mengunduh Photo Strip HD, video MP4, dan motion GIF ke smartphone.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Pricing Section -->
    <section id="harga" class="py-24 z-10 relative border-t border-white/5 bg-dark-900/40">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-2xl mx-auto text-center mb-16">
                <h2 class="text-xs font-bold tracking-widest text-brand-400 uppercase mb-3">Paket Berlangganan</h2>
                <p class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Investasi Terjangkau dengan Hasil Maksimal</p>
                <p class="text-sm text-slate-400 mt-4">Pilih paket lisensi software yang sesuai dengan skala bisnis atau cafe Anda.</p>
            </div>

            <!-- Pricing Cards Grid -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch">
                
                <!-- Plan 1: Starter -->
                <div class="rounded-2xl bg-dark-950 border border-white/10 p-8 flex flex-col justify-between transition duration-200 hover:border-white/20">
                    <div>
                        <div class="text-sm font-bold text-slate-300 uppercase tracking-wider mb-2">Starter</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Rp 500.000</span>
                            <span class="text-xs text-slate-400 font-medium">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-400 leading-relaxed mb-6">Cocok untuk cafe tunggal atau event organizer skala menengah yang ingin memulai photobooth mandiri.</p>

                        <div class="border-t border-white/5 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>1 Lisensi Device Kiosk Android</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Unlimited Sesi Foto & QR Cloud</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Output Photo Strip HD 300 DPI</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Hingga 15 Frame Kustom Aktif</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dashboard Laporan Penjualan Harian</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Masa Aktif Download Cloud 7 Hari</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo,%20saya%20tertarik%20dengan%20Paket%20Starter%20SnapTechBooth%20(500k/bulan)" target="_blank" class="w-full py-3 px-4 rounded-xl bg-dark-800 hover:bg-dark-700 text-white text-xs font-semibold text-center border border-white/10 transition">
                        Pilih Paket Starter
                    </a>
                </div>

                <!-- Plan 2: Pro Cafe (Featured) -->
                <div class="rounded-2xl bg-gradient-to-b from-dark-850 to-dark-950 border-2 border-brand-500 p-8 flex flex-col justify-between relative shadow-2xl shadow-brand-500/10 scale-105 z-20">
                    <div class="absolute -top-3.5 left-1/2 -translate-x-1/2 px-3.5 py-1 bg-brand-600 rounded-full text-[10px] font-extrabold uppercase tracking-wider text-white shadow-lg">
                        Paling Populer
                    </div>

                    <div>
                        <div class="text-sm font-bold text-brand-400 uppercase tracking-wider mb-2">Pro Cafe</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Rp 850.000</span>
                            <span class="text-xs text-slate-400 font-medium">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-400 leading-relaxed mb-6">Pilihan ideal untuk cafe & restoran ramai yang membutuhkan fitur otomatisasi pembayaran dan video motion.</p>

                        <div class="border-t border-white/10 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span><strong>Hingga 2 Device Kiosk</strong> (1 Cafe)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span><strong>Semua Output:</strong> Photo Strip + GIF + Video MP4</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span><strong>Integrasi QRIS Otomatis</strong> (Midtrans / Xendit)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Layanan Auto-Print Presisi & Cetak Latar</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Unlimited Frame Kustom + Frame Pencil Editor</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Custom Logo & Watermark Cafe</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-white">
                                <svg class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Prioritas Dukungan Teknis 24/7</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo,%20saya%20tertarik%20dengan%20Paket%20Pro%20Cafe%20SnapTechBooth%20(850k/bulan)" target="_blank" class="w-full py-3.5 px-4 rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-xs font-bold text-center shadow-lg shadow-brand-600/30 transition">
                        Pilih Paket Pro Cafe
                    </a>
                </div>

                <!-- Plan 3: Enterprise -->
                <div class="rounded-2xl bg-dark-950 border border-white/10 p-8 flex flex-col justify-between transition duration-200 hover:border-white/20">
                    <div>
                        <div class="text-sm font-bold text-slate-300 uppercase tracking-wider mb-2">Enterprise / Franchise</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">Rp 1.500.000</span>
                            <span class="text-xs text-slate-400 font-medium">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-400 leading-relaxed mb-6">Solusi lengkap untuk jaringan franchise, multi-outlet cafe, atau bisnis photobooth berskala besar.</p>

                        <div class="border-t border-white/5 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span><strong>Multi-Branch Management</strong> (Super Admin)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Master Frame Sync ke Seluruh Cabang</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Full White-Label (Domain & Brand Sendiri)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dedicated Cloud Storage & SLA 99.9%</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Integrasi AI Enhancement Custom</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs text-slate-300">
                                <svg class="w-4 h-4 text-brand-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dedicated Account Manager & Setup Konsultasi</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo,%20saya%20tertarik%20dengan%20Paket%20Enterprise%20SnapTechBooth%20(1.5jt/bulan)" target="_blank" class="w-full py-3 px-4 rounded-xl bg-dark-800 hover:bg-dark-700 text-white text-xs font-semibold text-center border border-white/10 transition">
                        Hubungi Enterprise
                    </a>
                </div>
            </div>
        </div>
    </section>

    <!-- FAQ Section -->
    <section id="faq" class="py-24 z-10 relative border-t border-white/5">
        <div class="max-w-4xl mx-auto px-6">
            <div class="text-center mb-16">
                <h2 class="text-xs font-bold tracking-widest text-brand-400 uppercase mb-3">Pertanyaan Umum</h2>
                <p class="text-3xl font-extrabold text-white tracking-tight">Kerap Ditanyakan</p>
            </div>

            <div class="space-y-4">
                <div class="p-6 rounded-2xl bg-dark-900/60 border border-white/5">
                    <h3 class="text-sm font-bold text-white mb-2">Hardware apa saja yang saya butuhkan untuk memulai?</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Anda hanya membutuhkan 1 unit tablet/layar Android (bisa menggunakan tablet standar atau all-in-one kiosk Android) dan 1 unit printer foto (seperti DNP RX1HS, Canon Selphy, atau Epson L-series).</p>
                </div>
                <div class="p-6 rounded-2xl bg-dark-900/60 border border-white/5">
                    <h3 class="text-sm font-bold text-white mb-2">Bagaimana sistem pembayaran QRIS bekerja di booth?</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Sistem terintegrasi dengan Payment Gateway (Midtrans/Xendit). QRIS dinamis akan muncul otomatis di layar kiosk. Begitu pelanggan membayar melalui mobile banking atau e-wallet, sesi foto langsung terbuka tanpa memerlukan tindakan kasir.</p>
                </div>
                <div class="p-6 rounded-2xl bg-dark-900/60 border border-white/5">
                    <h3 class="text-sm font-bold text-white mb-2">Apakah saya bisa mengganti desain frame foto sendiri?</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Tentu. Anda dapat mengunggah frame baru kapan saja melalui Dashboard Admin. Sistem dilengkapi alat pensil interaktif untuk melubangi kotak foto secara otomatis sesuai desain Anda.</p>
                </div>
                <div class="p-6 rounded-2xl bg-dark-900/60 border border-white/5">
                    <h3 class="text-sm font-bold text-white mb-2">Apakah ada biaya tambahan per sesi foto?</h3>
                    <p class="text-xs text-slate-400 leading-relaxed">Tidak ada. Semua paket berlangganan SnapTechBooth memiliki kuota sesi foto dan unduhan QR yang tidak terbatas (unlimited sessions).</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Bottom CTA Banner -->
    <section class="py-20 z-10 relative border-t border-white/5 bg-gradient-to-b from-dark-900 to-dark-950">
        <div class="max-w-4xl mx-auto px-6 text-center">
            <h2 class="text-3xl sm:text-4xl font-extrabold text-white tracking-tight mb-4">Siap Mengembangkan Bisnis Photobooth Anda?</h2>
            <p class="text-sm text-slate-400 mb-8 max-w-xl mx-auto">Konsultasikan kebutuhan cafe atau event Anda bersama tim kami. Uji coba sistem dan dapatkan panduan setup hardware lengkap.</p>
            <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
                <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20ingin%20tanya%20detail%20setup%20photobooth" target="_blank" class="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-bold text-sm shadow-xl shadow-brand-600/30 transition">
                    <span>Hubungi Kami via WhatsApp</span>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                    </svg>
                </a>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="border-t border-white/5 py-12 z-10 relative bg-dark-950">
        <div class="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-6">
            <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-lg bg-brand-600/10 border border-brand-500/30 flex items-center justify-center text-brand-500">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z"/>
                    </svg>
                </div>
                <span class="text-sm font-bold text-slate-300">SnapTechBooth © 2026</span>
            </div>

            <div class="flex items-center gap-6 text-xs text-slate-400">
                <a href="/admin" class="hover:text-white transition">Admin Panel</a>
                <a href="/super-admin" class="hover:text-white transition">Super Admin</a>
                <a href="#fitur" class="hover:text-white transition">Fitur</a>
                <a href="#harga" class="hover:text-white transition">Harga</a>
            </div>
        </div>
    </footer>

</body>
</html>
