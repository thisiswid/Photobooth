<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Download Foto — Fakultas Kopi Photobooth</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --dark-coffee: #2C1810;
            --dark-brown: #5C3A21;
            --warm-brown: #8C5331;
            --gold: #C89B5B;
            --gold-light: #E4C896;
            --parchment: #FAF6F0;
            --cream: #F5EFEB;
            --card-bg: #FFFFFF;
            --border-color: #EADDCF;
            --text-dark: #2C1810;
            --text-muted: #8A7264;
            --error-red: #A83232;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--parchment);
            color: var(--text-dark);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 20px 16px;
            background-image: radial-gradient(#dcc9b3 1px, transparent 1px);
            background-size: 24px 24px;
            -webkit-font-smoothing: antialiased;
        }

        .container {
            width: 100%;
            max-width: 460px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        /* SVG Icon Utilities */
        .icon {
            display: inline-block;
            width: 18px;
            height: 18px;
            stroke-width: 2;
            stroke: currentColor;
            fill: none;
            stroke-linecap: round;
            stroke-linejoin: round;
            vertical-align: middle;
        }

        .icon-sm {
            width: 15px;
            height: 15px;
        }

        .icon-lg {
            width: 20px;
            height: 20px;
        }

        /* Header */
        .brand-header {
            text-align: center;
            margin-top: 10px;
            margin-bottom: 20px;
        }

        .brand-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: var(--dark-coffee);
            color: var(--gold-light);
            padding: 6px 16px;
            border-radius: 30px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            box-shadow: 0 4px 12px rgba(44, 24, 16, 0.12);
        }

        .brand-title {
            font-family: 'Playfair Display', serif;
            font-size: 28px;
            font-weight: 800;
            color: var(--dark-coffee);
            margin-top: 12px;
            line-height: 1.2;
            letter-spacing: -0.3px;
        }

        .brand-subtitle {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 6px;
            letter-spacing: 0.2px;
        }

        /* Expiry Badge */
        .expiry-card {
            width: 100%;
            background: #FFFBF5;
            border: 1px solid var(--border-color);
            border-left: 4px solid var(--gold);
            border-radius: 12px;
            padding: 12px 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 18px;
            font-size: 12px;
            color: var(--dark-brown);
            box-shadow: 0 2px 8px rgba(0,0,0,0.03);
        }

        .expiry-info {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .expiry-badge {
            background: var(--dark-coffee);
            color: #FFFFFF;
            padding: 4px 10px;
            border-radius: 6px;
            font-weight: 700;
            font-size: 11px;
            letter-spacing: 0.3px;
            white-space: nowrap;
        }

        /* Preview Card */
        .preview-card {
            width: 100%;
            background: var(--card-bg);
            border-radius: 20px;
            padding: 18px;
            border: 1px solid var(--border-color);
            box-shadow: 0 10px 30px rgba(92, 58, 33, 0.08);
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 22px;
        }

        /* Media Switcher Tabs */
        .media-tabs {
            display: flex;
            width: 100%;
            background: var(--cream);
            border-radius: 12px;
            padding: 4px;
            margin-bottom: 16px;
            gap: 4px;
            border: 1px solid var(--border-color);
        }

        .tab-btn {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            padding: 9px 12px;
            border: none;
            background: transparent;
            font-family: inherit;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-muted);
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .tab-btn.active {
            background: var(--dark-coffee);
            color: #FFFFFF;
            box-shadow: 0 2px 8px rgba(0,0,0,0.12);
        }

        /* Media Display */
        .media-container {
            width: 100%;
            max-width: 320px;
            margin: 0 auto;
            border-radius: 12px;
            overflow: hidden;
            background: #FDFBF7;
            display: flex;
            justify-content: center;
            align-items: center;
            box-shadow: 0 6px 20px rgba(0,0,0,0.06);
            border: 1px solid var(--border-color);
        }

        .media-container img {
            width: 100%;
            height: auto;
            display: block;
            object-fit: contain;
        }

        /* Action Buttons */
        .action-group {
            width: 100%;
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-top: 18px;
        }

        .btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            width: 100%;
            padding: 14px 20px;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 700;
            text-decoration: none;
            transition: transform 0.15s ease, box-shadow 0.15s ease;
            cursor: pointer;
            border: none;
            letter-spacing: 0.3px;
        }

        .btn:active {
            transform: scale(0.98);
        }

        .btn-primary {
            background: var(--dark-coffee);
            color: #FFFFFF;
            box-shadow: 0 6px 16px rgba(44, 24, 16, 0.2);
        }

        .btn-gold {
            background: var(--gold);
            color: var(--dark-coffee);
            box-shadow: 0 6px 16px rgba(200, 155, 91, 0.25);
        }

        /* Individual Photos Section */
        .section-title {
            font-family: 'Playfair Display', serif;
            font-size: 18px;
            font-weight: 700;
            color: var(--dark-coffee);
            margin: 18px 0 12px 0;
            width: 100%;
            text-align: left;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .photos-grid {
            width: 100%;
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            margin-bottom: 24px;
        }

        .photo-item {
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid var(--border-color);
            box-shadow: 0 4px 10px rgba(0,0,0,0.03);
            display: flex;
            flex-direction: column;
        }

        .photo-thumb {
            width: 100%;
            aspect-ratio: 4 / 3;
            object-fit: cover;
            display: block;
        }

        .photo-download-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            padding: 10px 8px;
            font-size: 11px;
            font-weight: 700;
            text-align: center;
            background: var(--cream);
            color: var(--dark-brown);
            text-decoration: none;
            border-top: 1px solid var(--border-color);
            transition: background 0.2s ease;
        }

        .photo-download-btn:active {
            background: #EADDCF;
        }

        /* Expired Notice */
        .expired-card {
            background: #FFFFFF;
            border: 1.5px solid var(--border-color);
            border-radius: 16px;
            padding: 32px 20px;
            text-align: center;
            margin: 40px 0;
            box-shadow: 0 8px 24px rgba(0,0,0,0.04);
        }

        .expired-icon {
            width: 48px;
            height: 48px;
            margin: 0 auto 16px auto;
            color: var(--dark-brown);
            stroke-width: 1.5;
        }

        .expired-title {
            color: var(--dark-coffee);
            font-family: 'Playfair Display', serif;
            font-size: 22px;
            font-weight: 700;
            margin-bottom: 8px;
        }

        /* Footer */
        .footer {
            margin-top: auto;
            text-align: center;
            font-size: 11px;
            color: var(--text-muted);
            padding: 24px 0 16px 0;
            line-height: 1.6;
        }
    </style>
</head>
<body>

<div class="container">
    <!-- Header -->
    <header class="brand-header">
        <div class="brand-pill">
            <svg class="icon icon-sm" viewBox="0 0 24 24"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path><circle cx="12" cy="13" r="4"></circle></svg>
            FAKULTAS KOPI PHOTOBOOTH
        </div>
        <h1 class="brand-title">Hasil Foto</h1>
        <p class="brand-subtitle">Simpan momen berhargamu di sini</p>
    </header>

    @if($isExpired)
        <!-- Masa Aktif Habis -->
        <div class="expired-card">
            <svg class="icon expired-icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            <h2 class="expired-title">Masa Aktif Foto Berakhir</h2>
            <p style="font-size: 13px; color: var(--text-muted); line-height: 1.6; margin-top: 8px;">
                Foto sesi ini disimpan selama <strong>7 hari</strong> demi privasi dan manajemen ruang penyimpanan.
            </p>
            <p style="font-size: 12px; color: var(--text-muted); margin-top: 14px;">
                Silakan hubungi staf booth jika Anda memerlukan bantuan.
            </p>
        </div>
    @else
        <!-- Expiry countdown info -->
        <div class="expiry-card">
            <div class="expiry-info">
                <svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
                <div>
                    <div style="font-weight: 700; color: var(--dark-coffee);">Tersedia 7 Hari</div>
                    <div style="font-size: 11px; color: var(--text-muted);">
                        Hingga {{ $result->expires_at->translatedFormat('d M Y, H:i') }}
                    </div>
                </div>
            </div>
            <span class="expiry-badge">{{ $daysLeft > 0 ? $daysLeft . ' Hari Lagi' : $hoursLeft . ' Jam Lagi' }}</span>
        </div>

        <!-- Preview & Download Section -->
        <div class="preview-card">
            <!-- Tabs -->
            <div class="media-tabs">
                <button class="tab-btn active" onclick="switchMedia('strip')">
                    <svg class="icon icon-sm" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
                    Photo Strip
                </button>
                @if($gifUrl)
                    <button class="tab-btn" onclick="switchMedia('gif')">
                        <svg class="icon icon-sm" viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="20" rx="2.18" ry="2.18"></rect><line x1="7" y1="2" x2="7" y2="22"></line><line x1="17" y1="2" x2="17" y2="22"></line><line x1="2" y1="12" x2="22" y2="12"></line><line x1="2" y1="7" x2="7" y2="7"></line><line x1="2" y1="17" x2="7" y2="17"></line><line x1="17" y1="17" x2="22" y2="17"></line><line x1="17" y1="7" x2="22" y2="7"></line></svg>
                        Motion GIF
                    </button>
                @endif
            </div>

            <!-- Media Item 1: Photo Strip HD -->
            <div id="media-strip" class="media-container">
                @if($stripUrl)
                    <img src="{{ $stripUrl }}" alt="Photo Strip HD">
                @else
                    <div style="padding: 40px; color: var(--text-muted); font-size: 13px;">Photo strip sedang diproses...</div>
                @endif
            </div>

            <!-- Media Item 2: Animated GIF -->
            @if($gifUrl)
                <div id="media-gif" class="media-container" style="display: none;">
                    <img src="{{ $gifUrl }}" alt="Motion GIF Animation">
                </div>
            @endif

            <!-- Download Buttons -->
            <div class="action-group">
                <a href="{{ route('download.strip', $token) }}" class="btn btn-primary" id="btn-download-strip">
                    <svg class="icon icon-lg" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                    Download Photo Strip (HD)
                </a>

                @if($gifUrl)
                    <a href="{{ route('download.gif', $token) }}" class="btn btn-gold" id="btn-download-gif" style="display: none;">
                        <svg class="icon icon-lg" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                        Download Motion GIF
                    </a>
                @endif
            </div>
        </div>

        <!-- Individual Photos Grid -->
        @if($rawPhotos->isNotEmpty())
            <h3 class="section-title">
                <svg class="icon icon-sm" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
                Foto Satuan
            </h3>
            <div class="photos-grid">
                @foreach($rawPhotos as $idx => $p)
                    <div class="photo-item">
                        <img src="{{ asset('storage/' . $p->file_url) }}" alt="Pose {{ $idx + 1 }}" class="photo-thumb">
                        <a href="{{ route('download.photo', ['token' => $token, 'photoId' => $p->id]) }}" class="photo-download-btn">
                            <svg class="icon icon-sm" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                            Simpan Pose {{ $idx + 1 }}
                        </a>
                    </div>
                @endforeach
            </div>
        @endif
    @endif

    <!-- Footer -->
    <footer class="footer">
        <p>© {{ date('Y') }} Fakultas Kopi Photobooth</p>
        <p>Terima kasih telah berkunjung dan mengabadikan momen bersama kami.</p>
    </footer>
</div>

<script>
    function switchMedia(type) {
        const stripContainer = document.getElementById('media-strip');
        const gifContainer = document.getElementById('media-gif');
        const btnStrip = document.getElementById('btn-download-strip');
        const btnGif = document.getElementById('btn-download-gif');
        const tabs = document.querySelectorAll('.tab-btn');

        if (type === 'strip') {
            stripContainer.style.display = 'flex';
            if (gifContainer) gifContainer.style.display = 'none';
            btnStrip.style.display = 'flex';
            if (btnGif) btnGif.style.display = 'none';
            tabs[0].classList.add('active');
            if (tabs[1]) tabs[1].classList.remove('active');
        } else {
            stripContainer.style.display = 'none';
            if (gifContainer) gifContainer.style.display = 'flex';
            btnStrip.style.display = 'none';
            if (btnGif) btnGif.style.display = 'flex';
            tabs[0].classList.remove('active');
            if (tabs[1]) tabs[1].classList.add('active');
        }
    }
</script>

</body>
</html>
