<!DOCTYPE html>
<html lang="id" class="scroll-smooth">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SnapTechBooth — Software Photobooth Self-Service untuk Cafe & Event</title>
    <meta name="description" content="Software photobooth self-service: Kiosk Android, cetak otomatis 300 DPI, download QR ke smartphone, dan pembayaran QRIS mandiri untuk cafe dan event.">
    
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">

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
                        snap: {
                            teal: '#008B9B',
                            tealDark: '#035368',
                            cyan: '#00C4D6',
                            coral: '#E93C78',
                            magenta: '#8C206B',
                            orangeRed: '#FF5841',
                            orange: '#FFA234',
                            navy: '#0A2B42',
                        }
                    }
                }
            }
        }
    </script>

    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: #FAFAFD;
            color: #0A2B42;
        }
        .gradient-text-s {
            background: linear-gradient(135deg, #00C4D6 0%, #E93C78 50%, #8C206B 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .gradient-bg-main {
            background: linear-gradient(135deg, #008B9B 0%, #E93C78 50%, #FFA234 100%);
        }
        .blob-1 {
            background: radial-gradient(circle, rgba(0, 196, 214, 0.15) 0%, rgba(255, 255, 255, 0) 70%);
        }
        .blob-2 {
            background: radial-gradient(circle, rgba(233, 60, 120, 0.12) 0%, rgba(255, 255, 255, 0) 70%);
        }
        .blob-3 {
            background: radial-gradient(circle, rgba(255, 162, 52, 0.15) 0%, rgba(255, 255, 255, 0) 70%);
        }
    </style>
</head>
<body class="antialiased selection:bg-[#E93C78] selection:text-white relative overflow-x-hidden">

    <!-- Ambient Soft Blobs (No Grid Lines) -->
    <div class="fixed top-0 left-0 w-[550px] h-[550px] blob-1 pointer-events-none z-0 -translate-x-1/3 -translate-y-1/3"></div>
    <div class="fixed top-1/4 right-0 w-[600px] h-[600px] blob-2 pointer-events-none z-0 translate-x-1/4"></div>
    <div class="fixed bottom-10 left-1/3 w-[500px] h-[500px] blob-3 pointer-events-none z-0"></div>

    <!-- Navigation Header -->
    <header class="sticky top-0 z-50 backdrop-blur-lg bg-white/85 border-b border-slate-100 shadow-sm">
        <div class="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
            <!-- Brand Logo -->
            <a href="/" class="flex items-center gap-3 group">
                <img 
                    src="/logo/logo-snaptech.jpg" 
                    alt="SnapTechBooth Logo" 
                    class="w-11 h-11 rounded-2xl object-cover shadow-md shadow-[#008B9B]/20 border-2 border-white group-hover:scale-105 transition duration-300"
                    onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                />
                <div class="w-11 h-11 rounded-2xl gradient-bg-main items-center justify-center text-white hidden shadow-md">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z"/>
                    </svg>
                </div>
                <div class="flex flex-col">
                    <span class="text-xl font-black tracking-tight text-[#0A2B42]">SnapTech<span class="gradient-text-s">Booth</span></span>
                    <span class="text-[10px] text-slate-500 font-bold -mt-1 tracking-wider uppercase">Self-Photo Kiosk</span>
                </div>
            </a>

            <!-- Nav Links -->
            <nav class="hidden md:flex items-center gap-8 text-sm font-bold text-slate-600">
                <a href="#fitur" class="hover:text-[#008B9B] transition">Fitur</a>
                <a href="#cara-kerja" class="hover:text-[#E93C78] transition">Cara Kerja</a>
                <a href="#harga" class="hover:text-[#FF5841] transition">Pilihan Paket</a>
                <a href="#faq" class="hover:text-[#008B9B] transition">FAQ</a>
            </nav>

            <!-- Actions (Public Only) -->
            <div class="flex items-center gap-4">
                <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20tertarik%20dengan%20software%20photobooth%20untuk%20bisnis%20saya" target="_blank" class="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-gradient-to-r from-[#008B9B] via-[#E93C78] to-[#FFA234] hover:opacity-95 text-white text-sm font-extrabold shadow-lg shadow-[#E93C78]/25 hover:shadow-xl hover:scale-[1.02] transition duration-200">
                    <span>Konsultasi WhatsApp</span>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                    </svg>
                </a>
            </div>
        </div>
    </header>

    <!-- Hero Section -->
    <section class="relative pt-16 pb-20 z-10">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-3xl mx-auto text-center">
                <!-- Clean Badge -->
                <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white border border-slate-200/80 text-xs font-bold text-[#008B9B] shadow-sm mb-6">
                    <span class="w-2 h-2 rounded-full bg-[#E93C78] animate-ping"></span>
                    Software Photobooth Self-Service untuk Cafe & Event
                </div>

                <!-- Main Headline -->
                <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black text-[#0A2B42] tracking-tight leading-[1.18] mb-6">
                    Bikin Cafe & Event Kamu Makin Ramai dengan <span class="gradient-text-s">SnapTechBooth</span>
                </h1>

                <!-- Subheadline -->
                <p class="text-base sm:text-lg text-slate-600 leading-relaxed mb-10 max-w-2xl mx-auto font-medium">
                    Software photobooth otomatis yang mudah dipakai: pengunjung foto mandiri, cetak foto strip instan, unduh video & GIF ke HP via QR, serta bayar praktis lewat QRIS.
                </p>

                <!-- CTA Buttons -->
                <div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
                    <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20ingin%20tanya%20detail%20setup%20photobooth" target="_blank" class="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-gradient-to-r from-[#008B9B] via-[#E93C78] to-[#FF5841] hover:opacity-95 text-white font-extrabold text-sm shadow-xl shadow-[#E93C78]/30 hover:scale-[1.02] transition duration-200">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"/>
                        </svg>
                        <span>Konsultasi & Demo Gratis</span>
                    </a>
                    <a href="#harga" class="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-white hover:bg-slate-50 text-[#0A2B42] border-2 border-slate-200 font-extrabold text-sm shadow-sm transition duration-200">
                        <span>Lihat Pilihan Paket</span>
                        <svg class="w-4 h-4 text-[#FFA234]" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                        </svg>
                    </a>
                </div>
            </div>

            <!-- Showcase Preview Cards -->
            <div class="relative max-w-5xl mx-auto">
                <div class="rounded-3xl border-2 border-white bg-white/90 p-5 sm:p-7 shadow-2xl shadow-slate-200/80 backdrop-blur-xl">
                    <div class="flex items-center justify-between border-b border-slate-100 pb-4 mb-6">
                        <div class="flex items-center gap-2">
                            <div class="w-3.5 h-3.5 rounded-full bg-[#E93C78]"></div>
                            <div class="w-3.5 h-3.5 rounded-full bg-[#FFA234]"></div>
                            <div class="w-3.5 h-3.5 rounded-full bg-[#00C4D6]"></div>
                        </div>
                        <div class="text-xs font-bold text-slate-500 flex items-center gap-2 bg-slate-50 px-3 py-1.5 rounded-full border border-slate-100">
                            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                            Kiosk Android Mode • Siap Dipasang di Tablet
                        </div>
                        <div class="text-xs font-bold text-[#008B9B] hidden sm:block">SnapTech Experience</div>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 items-stretch">
                        
                        <!-- Card 1: Foto Mandiri -->
                        <div class="bg-gradient-to-b from-[#00C4D6]/10 to-[#008B9B]/5 border-2 border-[#00C4D6]/30 rounded-2xl p-6 flex flex-col justify-between">
                            <div>
                                <div class="w-10 h-10 rounded-xl bg-[#00C4D6]/20 flex items-center justify-center text-[#008B9B] mb-4">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                                    </svg>
                                </div>
                                <span class="text-[11px] font-extrabold uppercase tracking-wider text-[#008B9B]">Langkah 01</span>
                                <h3 class="text-base font-extrabold text-[#0A2B42] mt-1 mb-2">Foto Mandiri & Pilihan Frame</h3>
                                <p class="text-xs text-slate-600 leading-relaxed">Pengunjung memilih desain frame, berpose dengan aba-aba hitungan otomatis, dan bebas retake foto jika belum pas.</p>
                            </div>
                            <div class="mt-4 pt-3 border-t border-[#00C4D6]/20 flex items-center justify-between text-xs font-bold text-[#008B9B]">
                                <span>Multi-Pose Capture</span>
                                <span class="px-2 py-0.5 rounded-full bg-[#00C4D6]/20 text-[10px]">Cepat & Praktis</span>
                            </div>
                        </div>

                        <!-- Card 2: Cetak Strip & Media -->
                        <div class="bg-gradient-to-b from-[#E93C78]/10 to-[#8C206B]/5 border-2 border-[#E93C78]/30 rounded-2xl p-6 flex flex-col justify-between shadow-lg shadow-[#E93C78]/10">
                            <div>
                                <div class="w-10 h-10 rounded-xl bg-[#E93C78]/20 flex items-center justify-center text-[#E93C78] mb-4">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24-1.656-.613-3.195-1.12-4.577m0 0a15.82 15.82 0 016.4-1.252c1.786 0 3.498.286 5.093.816m-11.493.436C6.72 9.08 7.5 7.6 7.5 6a7.5 7.5 0 0115 0c0 1.6-.78 3.08-2.107 4.252"/>
                                    </svg>
                                </div>
                                <span class="text-[11px] font-extrabold uppercase tracking-wider text-[#E93C78]">Langkah 02</span>
                                <h3 class="text-base font-extrabold text-[#0A2B42] mt-1 mb-2">Cetak Cepat 300 DPI + GIF & Video</h3>
                                <p class="text-xs text-slate-600 leading-relaxed">Satu kali sesi foto langsung menghasilkan cetak fisik tajam, animasi GIF bergerak, dan file video MP4.</p>
                            </div>
                            <div class="mt-4 pt-3 border-t border-[#E93C78]/20 flex items-center justify-between text-xs font-bold text-[#E93C78]">
                                <span>Auto-Print Support</span>
                                <span class="px-2 py-0.5 rounded-full bg-[#E93C78]/20 text-[10px]">Kualitas Tinggi</span>
                            </div>
                        </div>

                        <!-- Card 3: Scan QR Download -->
                        <div class="bg-gradient-to-b from-[#FFA234]/15 to-[#FF5841]/5 border-2 border-[#FFA234]/40 rounded-2xl p-6 flex flex-col justify-between">
                            <div>
                                <div class="w-10 h-10 rounded-xl bg-[#FFA234]/20 flex items-center justify-center text-[#FF5841] mb-4">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0113.5 9.375v-4.5z"/>
                                    </svg>
                                </div>
                                <span class="text-[11px] font-extrabold uppercase tracking-wider text-[#FF5841]">Langkah 03</span>
                                <h3 class="text-base font-extrabold text-[#0A2B42] mt-1 mb-2">Scan QR Langsung ke HP</h3>
                                <p class="text-xs text-slate-600 leading-relaxed">Pengunjung scan QR code di layar booth untuk simpan semua foto dan video tanpa harus download aplikasi.</p>
                            </div>
                            <div class="mt-4 pt-3 border-t border-[#FFA234]/20 flex items-center justify-between text-xs font-bold text-[#FF5841]">
                                <span>Instant Cloud Download</span>
                                <span class="px-2 py-0.5 rounded-full bg-[#FFA234]/20 text-[10px]">Tanpa Aplikasi</span>
                            </div>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Core Features Grid -->
    <section id="fitur" class="py-24 z-10 relative bg-white border-t border-b border-slate-100">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-2xl mx-auto text-center mb-16">
                <span class="px-3.5 py-1.5 rounded-full bg-[#008B9B]/10 text-xs font-extrabold text-[#008B9B] uppercase tracking-wider">Fitur Utama</span>
                <h2 class="text-3xl sm:text-4xl font-black text-[#0A2B42] tracking-tight mt-3">Semua Kebutuhan Photobooth dalam Satu Aplikasi</h2>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                <!-- Feature 1: Kiosk Android -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#00C4D6] hover:shadow-xl hover:shadow-[#00C4D6]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#00C4D6]/15 flex items-center justify-center text-[#008B9B] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Aplikasi Kiosk Android</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Cukup pasang di tablet atau layar Android. Tampilan full-screen yang simpel dan siap melayani pengunjung seharian.</p>
                </div>

                <!-- Feature 2: Frame Editor & Green Eraser -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#E93C78] hover:shadow-xl hover:shadow-[#E93C78]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#E93C78]/15 flex items-center justify-center text-[#E93C78] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0l2.77-2.77m-2.77 2.77l-1.5 1.5m6.77-6.77l2.77-2.77a2.25 2.25 0 000-3.182l-1.364-1.364a2.25 2.25 0 00-3.182 0l-2.77 2.77m4.546 4.546l-4.546-4.546m0 0L3.75 14.25v3.75h3.75l9.25-9.25z"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Frame Builder & Hapus Warna Hijau</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Bebas upload template frame PNG atau gunakan alat pensil sekali klik untuk melubangi area foto secara otomatis.</p>
                </div>

                <!-- Feature 3: Auto-Print -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#FFA234] hover:shadow-xl hover:shadow-[#FFA234]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#FFA234]/20 flex items-center justify-center text-[#FF5841] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24-1.656-.613-3.195-1.12-4.577m0 0a15.82 15.82 0 016.4-1.252c1.786 0 3.498.286 5.093.816m-11.493.436C6.72 9.08 7.5 7.6 7.5 6a7.5 7.5 0 0115 0c0 1.6-.78 3.08-2.107 4.252"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Cetak Otomatis (Auto-Print)</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Mendukung berbagai printer foto (DNP, Canon Selphy, Epson). Begitu sesi selesai, foto langsung dicetak otomatis.</p>
                </div>

                <!-- Feature 4: QRIS Self-Payment -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#FF5841] hover:shadow-xl hover:shadow-[#FF5841]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#FF5841]/15 flex items-center justify-center text-[#FF5841] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Pembayaran QRIS Mandiri</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Terhubung langsung dengan QRIS (Gopay, OVO, Dana, BCA, dll). Sesi foto otomatis terbuka begitu pembayaran diterima.</p>
                </div>

                <!-- Feature 5: Cloud Dashboard -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#008B9B] hover:shadow-xl hover:shadow-[#008B9B]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#008B9B]/15 flex items-center justify-center text-[#008B9B] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Dashboard Penjualan Real-Time</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Pantau laporan transaksi, jumlah sesi per hari, dan atur katalog frame langsung dari HP atau laptop Anda.</p>
                </div>

                <!-- Feature 6: Filter Preset Estetik -->
                <div class="p-8 rounded-3xl bg-[#FAFAFD] border-2 border-slate-100 hover:border-[#8C206B] hover:shadow-xl hover:shadow-[#8C206B]/10 transition duration-300">
                    <div class="w-12 h-12 rounded-2xl bg-[#8C206B]/15 flex items-center justify-center text-[#8C206B] mb-6">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4.098 19.902a3.75 3.75 0 005.304 0l6.401-6.402M6.75 21A3.75 3.75 0 013 17.25V4.125C3 3.504 3.504 3 4.125 3h5.25c.621 0 1.125.504 1.125 1.125v4.072M6.75 21a3.75 3.75 0 003.75-3.75V8.197M6.75 21h13.125c.621 0 1.125-.504 1.125-1.125v-5.25c0-.621-.504-1.125-1.125-1.125h-4.072M10.5 8.197l9.402 9.402"/>
                        </svg>
                    </div>
                    <h3 class="text-lg font-extrabold text-[#0A2B42] mb-2">Pilihan Filter Foto</h3>
                    <p class="text-sm text-slate-600 leading-relaxed">Dilengkapi filter warna populer seperti Black & White, Warm Vintage, dan Soft Tone untuk hasil foto yang menarik.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Pricing Section -->
    <section id="harga" class="py-24 z-10 relative">
        <div class="max-w-7xl mx-auto px-6">
            <div class="max-w-2xl mx-auto text-center mb-16">
                <span class="px-3.5 py-1.5 rounded-full bg-[#E93C78]/10 text-xs font-extrabold text-[#E93C78] uppercase tracking-wider">Paket & Harga</span>
                <h2 class="text-3xl sm:text-4xl font-black text-[#0A2B42] tracking-tight mt-3">Investasi Terjangkau, Hasil Maksimal</h2>
                <p class="text-sm text-slate-600 mt-3 font-medium">Pilih paket langganan software yang paling pas untuk cafe atau bisnis photobooth Anda.</p>
            </div>

            <!-- Pricing Cards Grid -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8 items-stretch">
                
                <!-- Plan 1: Starter -->
                <div class="rounded-3xl bg-white border-2 border-slate-200/80 p-8 flex flex-col justify-between hover:border-[#008B9B] hover:shadow-xl hover:shadow-[#008B9B]/10 transition duration-300">
                    <div>
                        <div class="text-xs font-extrabold text-[#008B9B] uppercase tracking-wider mb-2">Starter</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-black text-[#0A2B42] tracking-tight">Rp 500.000</span>
                            <span class="text-xs text-slate-500 font-bold">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-600 leading-relaxed mb-6 font-medium">Pilihan pas untuk cafe tunggal atau event pemula yang ingin langsung mulai jualan photobooth.</p>

                        <div class="border-t border-slate-100 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>1 Lisensi Kiosk Android</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Unlimited Sesi Foto & QR Cloud</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Output Photo Strip HD 300 DPI</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Hingga 15 Frame Kustom Aktif</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Laporan Omset & Grafik Penjualan</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#008B9B] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Masa Simpan Download 7 Hari</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20tertarik%20dengan%20Paket%20Starter%20(500k/bulan)" target="_blank" class="w-full py-3.5 px-4 rounded-full bg-slate-100 hover:bg-[#008B9B] hover:text-white text-[#0A2B42] text-xs font-extrabold text-center transition duration-200">
                        Pilih Paket Starter
                    </a>
                </div>

                <!-- Plan 2: Pro Cafe (Paling Favorit) -->
                <div class="rounded-3xl bg-white border-2 border-[#E93C78] p-8 flex flex-col justify-between relative shadow-2xl shadow-[#E93C78]/20 scale-105 z-20">
                    <div class="absolute -top-3.5 left-1/2 -translate-x-1/2 px-4 py-1 bg-gradient-to-r from-[#E93C78] to-[#FF5841] rounded-full text-[10px] font-black uppercase tracking-wider text-white shadow-md">
                        Paling Favorit
                    </div>

                    <div>
                        <div class="text-xs font-extrabold text-[#E93C78] uppercase tracking-wider mb-2">Pro Cafe</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-black text-[#0A2B42] tracking-tight">Rp 850.000</span>
                            <span class="text-xs text-slate-500 font-bold">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-600 leading-relaxed mb-6 font-medium">Solusi terbaik untuk cafe & resto ramai dengan fitur pembayaran QRIS otomatis dan video motion.</p>

                        <div class="border-t border-slate-100 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Hingga 2 Device Kiosk (1 Cafe)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Semua Aset: Photo Strip + GIF + Video MP4</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Integrasi QRIS Otomatis (Midtrans/Xendit)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Layanan Auto-Print Presisi 300 DPI</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Unlimited Frame Kustom + Frame Pencil Editor</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Custom Logo & Watermark Cafe</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-bold text-[#0A2B42]">
                                <svg class="w-4 h-4 text-[#E93C78] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dukungan Prioritas WhatsApp 24/7</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20tertarik%20dengan%20Paket%20Pro%20Cafe%20(850k/bulan)" target="_blank" class="w-full py-4 px-4 rounded-full bg-gradient-to-r from-[#E93C78] via-[#FF5841] to-[#FFA234] hover:opacity-95 text-white text-xs font-black text-center shadow-lg shadow-[#E93C78]/25 transition duration-200">
                        Pilih Paket Pro Cafe
                    </a>
                </div>

                <!-- Plan 3: Enterprise -->
                <div class="rounded-3xl bg-white border-2 border-slate-200/80 p-8 flex flex-col justify-between hover:border-[#FFA234] hover:shadow-xl hover:shadow-[#FFA234]/10 transition duration-300">
                    <div>
                        <div class="text-xs font-extrabold text-[#FFA234] uppercase tracking-wider mb-2">Enterprise / Franchise</div>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl sm:text-4xl font-black text-[#0A2B42] tracking-tight">Rp 1.500.000</span>
                            <span class="text-xs text-slate-500 font-bold">/ bulan</span>
                        </div>
                        <p class="text-xs text-slate-600 leading-relaxed mb-6 font-medium">Lengkap untuk jaringan cabang, franchise, mall, dan bisnis photobooth multi-outlet.</p>

                        <div class="border-t border-slate-100 pt-6 space-y-3.5 mb-8">
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Multi-Cabang (Super Admin Terpusat)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Sinkronisasi Master Frame ke Semua Outlet</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Full White-Label (Domain & Brand Sendiri)</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dedicated Cloud Storage & SLA 99.9%</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Integrasi AI Enhancement Custom</span>
                            </div>
                            <div class="flex items-start gap-3 text-xs font-semibold text-slate-700">
                                <svg class="w-4 h-4 text-[#FFA234] shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/></svg>
                                <span>Dedicated Account Manager & Setup Pendampingan</span>
                            </div>
                        </div>
                    </div>

                    <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20tertarik%20dengan%20Paket%20Enterprise%20(1.5jt/bulan)" target="_blank" class="w-full py-3.5 px-4 rounded-full bg-slate-100 hover:bg-[#FFA234] hover:text-white text-[#0A2B42] text-xs font-extrabold text-center transition duration-200">
                        Hubungi Enterprise
                    </a>
                </div>
            </div>
        </div>
    </section>

    <!-- FAQ Section -->
    <section id="faq" class="py-24 z-10 relative bg-white border-t border-slate-100">
        <div class="max-w-4xl mx-auto px-6">
            <div class="text-center mb-16">
                <span class="px-3.5 py-1.5 rounded-full bg-[#008B9B]/10 text-xs font-extrabold text-[#008B9B] uppercase tracking-wider">Tanya Jawab</span>
                <h2 class="text-3xl font-black text-[#0A2B42] tracking-tight mt-3">Pertanyaan yang Sering Diajukan</h2>
            </div>

            <div class="space-y-4">
                <div class="p-6 rounded-2xl bg-[#FAFAFD] border-2 border-slate-100">
                    <h3 class="text-sm font-extrabold text-[#0A2B42] mb-2">Hardware apa saja yang dibutuhkan untuk mulai?</h3>
                    <p class="text-xs text-slate-600 leading-relaxed">Cukup 1 unit tablet/display Android (bisa tablet biasa atau stand kiosk Android) dan 1 unit printer foto (seperti DNP RX1HS, Canon Selphy, atau Epson L-series). Tim kami siap membantu panduan setup!</p>
                </div>
                <div class="p-6 rounded-2xl bg-[#FAFAFD] border-2 border-slate-100">
                    <h3 class="text-sm font-extrabold text-[#0A2B42] mb-2">Bagaimana cara kerja pembayaran QRIS di booth?</h3>
                    <p class="text-xs text-slate-600 leading-relaxed">Sistem terhubung langsung dengan QRIS dinamis di layar kiosk. Begitu tamu scan dan bayar, sesi foto otomatis terbuka tanpa perlu konfirmasi kasir.</p>
                </div>
                <div class="p-6 rounded-2xl bg-[#FAFAFD] border-2 border-slate-100">
                    <h3 class="text-sm font-extrabold text-[#0A2B42] mb-2">Apakah saya bisa ganti desain frame foto sendiri?</h3>
                    <p class="text-xs text-slate-600 leading-relaxed">Bisa banget! Anda bisa upload desain PNG dari Canva/Photoshop kapan saja. Sistem juga punya fitur alat pensil untuk melubangi kotak warna penanda foto secara otomatis.</p>
                </div>
                <div class="p-6 rounded-2xl bg-[#FAFAFD] border-2 border-slate-100">
                    <h3 class="text-sm font-extrabold text-[#0A2B42] mb-2">Apakah ada batasan jumlah sesi foto per bulan?</h3>
                    <p class="text-xs text-slate-600 leading-relaxed">Tidak ada batasan (Unlimited)! Berapapun jumlah foto dan unduhan QR yang dilakukan tamu di booth Anda, tidak ada biaya tambahan per sesi.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Bottom CTA Banner -->
    <section class="py-20 z-10 relative bg-gradient-to-r from-[#008B9B] via-[#E93C78] to-[#FFA234] text-white">
        <div class="max-w-4xl mx-auto px-6 text-center">
            <h2 class="text-3xl sm:text-4xl font-black tracking-tight mb-4">Siap Bikin Photobooth Sendiri di Cafe Kamu?</h2>
            <p class="text-sm text-white/90 mb-8 max-w-xl mx-auto font-medium">Konsultasikan kebutuhan tempat dan konsep bisnismu bersama tim kami. Dapatkan panduan setup hardware dan uji coba sistem secara gratis!</p>
            <div class="flex items-center justify-center">
                <a href="https://wa.me/6281234567890?text=Halo%20SnapTechBooth,%20saya%20mau%20konsultasi%20paket%20photobooth" target="_blank" class="inline-flex items-center justify-center gap-2 px-9 py-4 rounded-full bg-white hover:bg-slate-50 text-[#0A2B42] font-black text-sm shadow-2xl hover:scale-105 transition duration-200">
                    <span>Chat WhatsApp Sekarang</span>
                    <svg class="w-4 h-4 text-[#E93C78]" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                    </svg>
                </a>
            </div>
        </div>
    </section>

    <!-- Footer (Public, No Admin Links) -->
    <footer class="py-12 z-10 relative bg-[#FAFAFD] border-t border-slate-200">
        <div class="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-6">
            <div class="flex items-center gap-3">
                <img src="/logo/logo-snaptech.jpg" alt="Logo" class="w-8 h-8 rounded-xl object-cover border border-slate-200 shadow-sm" onerror="this.style.display='none';">
                <span class="text-sm font-black text-[#0A2B42]">SnapTech<span class="gradient-text-s">Booth</span> <span class="text-slate-400 font-normal text-xs ml-1">© 2026</span></span>
            </div>

            <div class="flex items-center gap-8 text-xs font-bold text-slate-500">
                <a href="#fitur" class="hover:text-[#008B9B] transition">Fitur</a>
                <a href="#cara-kerja" class="hover:text-[#E93C78] transition">Cara Kerja</a>
                <a href="#harga" class="hover:text-[#FFA234] transition">Pilihan Paket</a>
                <a href="#faq" class="hover:text-[#008B9B] transition">FAQ</a>
                <a href="https://wa.me/6281234567890" target="_blank" class="text-[#E93C78] hover:underline">Kontak Tim Sales</a>
            </div>
        </div>
    </footer>

</body>
</html>
