@php
    $seo = config('seo_pages');
    $biz = $seo['business'];
    $waBase = 'https://wa.me/'.$biz['whatsapp'];
    $wa = fn (string $text) => $waBase.'?text='.rawurlencode($text);
    $citiesByProvince = collect($seo['cities'])->groupBy('province', true);
@endphp
<!DOCTYPE html>
<html lang="id" class="scroll-smooth">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#f3e7cf">
    <title>{{ $meta['title'] }}</title>
    <meta name="description" content="{{ $meta['description'] }}">
    <meta name="robots" content="index, follow, max-image-preview:large">
    <link rel="canonical" href="{{ $meta['canonical'] }}">

    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="icon" type="image/png" sizes="192x192" href="/icon-192.png">
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">

    <meta property="og:type" content="website">
    <meta property="og:locale" content="id_ID">
    <meta property="og:site_name" content="SnapTechBooth">
    <meta property="og:url" content="{{ $meta['canonical'] }}">
    <meta property="og:title" content="{{ $meta['title'] }}">
    <meta property="og:description" content="{{ $meta['description'] }}">
    <meta property="og:image" content="{{ $meta['image'] }}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:image:alt" content="{{ $meta['image_alt'] }}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{ $meta['title'] }}">
    <meta name="twitter:description" content="{{ $meta['description'] }}">
    <meta name="twitter:image" content="{{ $meta['image'] }}">

    <script type="application/ld+json">{!! json_encode(['@context' => 'https://schema.org', '@graph' => $schema], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) !!}</script>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&family=Shrikhand&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = { theme: { extend: {
            fontFamily: { sans: ['DM Sans','sans-serif'], display: ['Shrikhand','serif'] },
            colors: { ink:'#2c201a', cream:'#f3e7cf', paper:'#fffaf0', tomato:'#d95336', mustard:'#e4aa3a', teal:'#28766f', blush:'#e8a594' }
        } } };
    </script>
    <style>
        :root{--ink:#2c201a;--cream:#f3e7cf;--paper:#fffaf0;--tomato:#d95336;--mustard:#e4aa3a;--teal:#28766f;--blush:#e8a594}
        *{box-sizing:border-box}body{margin:0;color:var(--ink);background:var(--cream);font-family:'DM Sans',sans-serif;overflow-x:hidden}
        body:before{content:'';position:fixed;inset:0;z-index:100;pointer-events:none;opacity:.14;background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.92' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.28'/%3E%3C/svg%3E");mix-blend-mode:multiply}
        ::selection{color:var(--paper);background:var(--tomato)}
        .display{font-family:'Shrikhand',serif;font-weight:400}
        .label{display:inline-flex;align-items:center;gap:.45rem;padding:.45rem .85rem;border:2px solid var(--ink);border-radius:999px;background:var(--mustard);box-shadow:3px 3px 0 var(--ink);font-size:.7rem;font-weight:800;letter-spacing:.12em;text-transform:uppercase}
        .sunburst{background:radial-gradient(circle at 78% 50%,transparent 0 18%,rgba(255,250,240,.3) 18.5% 20%,transparent 20.5%),repeating-conic-gradient(from -5deg at 78% 50%,rgba(255,250,240,.22) 0 8deg,transparent 8deg 17deg),var(--tomato)}
        .sunburst-teal{background:repeating-conic-gradient(from 0deg at 80% 50%,rgba(255,250,240,.16) 0 7deg,transparent 7deg 15deg),var(--teal)}
        .card{position:relative;border:2px solid var(--ink);background:var(--paper);box-shadow:6px 7px 0 var(--ink);transition:transform .25s,box-shadow .25s}
        a.card:hover,.card.hoverable:hover{transform:translate(-3px,-4px);box-shadow:10px 12px 0 var(--ink)}
        .chip{display:inline-flex;align-items:center;border:2px solid var(--ink);border-radius:999px;padding:.4rem .9rem;font-size:.75rem;font-weight:800;background:var(--paper)}
        .btn{display:inline-flex;align-items:center;justify-content:center;gap:.4rem;border:2px solid var(--ink);border-radius:999px;padding:.95rem 1.6rem;font-size:.875rem;font-weight:900;transition:transform .2s}
        .btn:hover{transform:translateY(-3px)}.btn-shadow{box-shadow:6px 7px 0 var(--ink)}
        .hero-figure{border:3px solid var(--ink);border-radius:28px;background:var(--paper);padding:10px;box-shadow:14px 16px 0 var(--ink);transform:rotate(1.5deg)}
        .hero-figure img{display:block;width:100%;height:auto;border-radius:18px;border:2px solid var(--ink)}
        .prose-snap p{line-height:1.75;font-weight:500;color:rgba(44,32,26,.78)}
        details summary{list-style:none;cursor:pointer}details summary::-webkit-details-marker{display:none}details[open] .plus{transform:rotate(45deg);background:var(--tomato);color:var(--paper)}.plus{transition:.25s}
        .step-num{display:grid;place-items:center;width:44px;height:44px;flex-shrink:0;border:2px solid var(--ink);border-radius:999px;background:var(--mustard);font-weight:900}
        @media(prefers-reduced-motion:reduce){*,*:before,*:after{transition-duration:.01ms!important}}
    </style>
</head>
<body>
<a href="#konten" class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[200] focus:rounded-full focus:bg-paper focus:px-4 focus:py-2">Langsung ke konten</a>

<header class="sticky top-0 z-50 border-b-2 border-ink bg-cream/95 backdrop-blur-md">
    <div class="mx-auto flex h-[74px] max-w-7xl items-center justify-between px-5 lg:px-8">
        <a href="/" class="flex items-center gap-3" aria-label="SnapTechBooth — beranda">
            <span class="grid h-11 w-11 -rotate-3 place-items-center overflow-hidden rounded-xl border-2 border-ink bg-paper shadow-[3px_3px_0_#2c201a]"><img src="/logo/logo-snaptech-512.jpg" width="44" height="44" alt="" class="h-full w-full object-cover"></span>
            <span><b class="display block text-xl leading-none">SnapTechBooth</b><small class="text-[9px] font-black uppercase tracking-[.22em] text-teal">Photobooth • Magetan</small></span>
        </a>
        <nav class="hidden items-center gap-6 text-sm font-bold lg:flex" aria-label="Navigasi utama">
            <a href="/photobooth-wedding" class="hover:text-tomato">Wedding</a>
            <a href="/photobooth-cafe" class="hover:text-tomato">Cafe</a>
            <a href="/photobooth-event" class="hover:text-tomato">Event</a>
            <a href="/aplikasi-photobooth" class="hover:text-tomato">Aplikasi</a>
            <a href="/area-layanan" class="hover:text-tomato">Area Layanan</a>
            <a href="/#harga" class="hover:text-tomato">Paket</a>
        </nav>
        <div class="flex items-center gap-2">
            <a href="{{ $wa('Halo SnapTechBooth, saya ingin konsultasi photobooth.') }}" target="_blank" rel="noopener" class="hidden rounded-full border-2 border-ink bg-tomato px-5 py-2.5 text-xs font-black text-paper shadow-[3px_3px_0_#2c201a] transition hover:-translate-y-0.5 sm:inline-flex">Chat WhatsApp</a>
            <button id="menu-button" class="grid h-10 w-10 place-items-center rounded-full border-2 border-ink bg-paper lg:hidden" aria-label="Buka menu" aria-expanded="false" aria-controls="mobile-menu">☰</button>
        </div>
    </div>
    <nav id="mobile-menu" class="hidden border-t-2 border-ink bg-paper px-5 py-4 lg:hidden" aria-label="Navigasi seluler">
        <div class="grid grid-cols-2 gap-3 text-sm font-bold">
            <a href="/photobooth-wedding">Wedding</a><a href="/photobooth-cafe">Cafe</a>
            <a href="/photobooth-event">Event</a><a href="/photobooth-wisuda">Wisuda</a>
            <a href="/sewa-photobooth">Sewa</a><a href="/aplikasi-photobooth">Aplikasi</a>
            <a href="/area-layanan">Area Layanan</a><a href="/#harga">Paket</a>
            <a href="{{ $wa('Halo SnapTechBooth, saya ingin konsultasi photobooth.') }}" target="_blank" rel="noopener" class="col-span-2 rounded-full border-2 border-ink bg-tomato px-4 py-3 text-center text-paper">Chat WhatsApp</a>
        </div>
    </nav>
</header>

<main id="konten">
    @yield('content')
</main>

<footer class="bg-ink text-paper">
    <div class="mx-auto grid max-w-7xl gap-10 px-5 py-14 sm:grid-cols-2 lg:grid-cols-4 lg:px-8">
        <div>
            <b class="display text-2xl">SnapTechBooth</b>
            <p class="mt-3 text-sm leading-relaxed text-paper/70">Photobooth self-service & software photobooth. Berbasis di {{ $biz['base_city'] }}, {{ $biz['base_region'] }}.</p>
            <p class="mt-4 text-sm font-bold">WhatsApp: <a class="underline decoration-mustard underline-offset-4" href="{{ $waBase }}" target="_blank" rel="noopener">{{ $biz['phone_display'] }}</a></p>
        </div>
        <div>
            <p class="text-xs font-black uppercase tracking-[.18em] text-mustard">Layanan</p>
            <ul class="mt-4 space-y-2 text-sm">
                @foreach ($seo['services'] as $s => $svc)
                    <li><a href="/{{ $s }}" class="text-paper/80 hover:text-mustard">{{ $svc['name'] }}</a></li>
                @endforeach
            </ul>
        </div>
        <div>
            <p class="text-xs font-black uppercase tracking-[.18em] text-mustard"><a href="/photobooth-jawa-timur" class="hover:underline">Jawa Timur</a></p>
            <ul class="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                @foreach ($citiesByProvince['Jawa Timur'] ?? [] as $s => $city)
                    <li><a href="/{{ $s }}" class="text-paper/80 hover:text-mustard">{{ $city['name'] }}</a></li>
                @endforeach
            </ul>
        </div>
        <div>
            <p class="text-xs font-black uppercase tracking-[.18em] text-mustard"><a href="/photobooth-jawa-tengah" class="hover:underline">Jawa Tengah</a> & lainnya</p>
            <ul class="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                @foreach ($seo['cities'] as $s => $city)
                    @continue($city['province'] === 'Jawa Timur')
                    <li><a href="/{{ $s }}" class="text-paper/80 hover:text-mustard">{{ $city['name'] }}</a></li>
                @endforeach
            </ul>
        </div>
    </div>
    <div class="border-t border-paper/15">
        <p class="mx-auto max-w-7xl px-5 py-6 text-xs text-paper/50 lg:px-8">© {{ date('Y') }} SnapTechBooth · <a href="/area-layanan" class="hover:text-paper">Area layanan</a> · <a href="/" class="hover:text-paper">Beranda</a></p>
    </div>
</footer>

<script>
(() => {
    const b = document.getElementById('menu-button'), m = document.getElementById('mobile-menu');
    b?.addEventListener('click', () => { const o = b.getAttribute('aria-expanded') === 'true'; b.setAttribute('aria-expanded', String(!o)); m.classList.toggle('hidden'); });
})();
</script>
</body>
</html>
