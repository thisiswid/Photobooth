<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use Illuminate\Contracts\View\View;

/**
 * Halaman pemasaran untuk SEO: layanan (/photobooth-wedding, ...),
 * kota (/photobooth-madiun, ...), provinsi (/photobooth-jawa-timur, ...)
 * dan hub /area-layanan. Semua konten ada di config/seo_pages.php.
 */
class SeoPageController extends Controller
{
    /** Semua slug yang dilayani route /{slug}. */
    public static function slugs(): array
    {
        return array_merge(
            array_keys(config('seo_pages.services', [])),
            array_keys(config('seo_pages.cities', [])),
            array_keys(config('seo_pages.regions', [])),
        );
    }

    public function show(string $slug): View
    {
        $c = config('seo_pages');

        if (isset($c['services'][$slug])) {
            return $this->service($slug, $c['services'][$slug]);
        }
        if (isset($c['cities'][$slug])) {
            return $this->city($slug, $c['cities'][$slug]);
        }
        if (isset($c['regions'][$slug])) {
            return $this->region($slug, $c['regions'][$slug]);
        }

        abort(404);
    }

    protected function service(string $slug, array $page): View
    {
        $url = $this->url($slug);

        $schema = [
            $this->business(),
            [
                '@type' => 'Service',
                '@id' => $url.'#service',
                'name' => $page['name'],
                'serviceType' => $page['name'],
                'description' => $page['description'],
                'url' => $url,
                'image' => $this->url('images/seo/'.$page['image'].'.webp'),
                'provider' => ['@id' => $this->businessId()],
                'areaServed' => [
                    ['@type' => 'State', 'name' => 'Jawa Timur'],
                    ['@type' => 'State', 'name' => 'Jawa Tengah'],
                ],
            ],
            $this->breadcrumb([
                ['Beranda', $this->url('')],
                [$page['name'], $url],
            ]),
            $this->faqSchema($page['faq']),
        ];

        return view('seo.service', [
            'slug' => $slug,
            'page' => $page,
            'meta' => $this->meta($slug, $page['title'], $page['description'], $page['image_alt']),
            'schema' => $schema,
        ]);
    }

    protected function city(string $slug, array $page): View
    {
        $url = $this->url($slug);
        $tier = config('seo_pages.tiers.'.$page['tier']);
        $fullName = $page['full_name'] ?? $page['name'];
        $isRemote = $page['tier'] === 'jauh';

        $title = $isRemote
            ? "Photobooth {$page['name']}: Aplikasi & Software Photobooth Self-Service | SnapTechBooth"
            : "Photobooth {$page['name']}: Sewa untuk Wedding, Event & Cafe | SnapTechBooth";
        $description = $isRemote
            ? "Software photobooth self-service untuk cafe dan vendor di {$fullName}: QRIS otomatis, cetak 300 DPI, GIF & video, dashboard multi-device. Dipasang dan dikonfigurasi dari jarak jauh."
            : "Photobooth di {$fullName} untuk wedding, event, wisuda, dan cafe. Frame custom, cetak instan 300 DPI, GIF & video via QR. Berangkat dari Magetan, {$page['drive']} perjalanan.";
        if ($page['tier'] === 'base') {
            $description = 'Photobooth di Magetan untuk wedding, event, wisuda, dan cafe. Base SnapTechBooth ada di Magetan: frame custom, cetak instan 300 DPI, GIF & video via QR, dan jadwal paling fleksibel.';
        }

        $faq = $this->cityFaq($page, $fullName);

        $schema = [
            $this->business(),
            [
                '@type' => 'Service',
                '@id' => $url.'#service',
                'name' => 'Photobooth '.$page['name'],
                'serviceType' => 'Photobooth',
                'description' => $description,
                'url' => $url,
                'provider' => ['@id' => $this->businessId()],
                'areaServed' => [
                    '@type' => 'City',
                    'name' => $page['name'],
                    'containedInPlace' => ['@type' => 'State', 'name' => $page['province']],
                ],
            ],
            $this->breadcrumb([
                ['Beranda', $this->url('')],
                ['Area Layanan', $this->url('area-layanan')],
                ['Photobooth '.$page['name'], $url],
            ]),
            $this->faqSchema($faq),
        ];

        return view('seo.city', [
            'slug' => $slug,
            'page' => $page,
            'fullName' => $fullName,
            'tier' => $tier,
            'isRemote' => $isRemote,
            'faq' => $faq,
            'meta' => $this->meta($slug, $title, $description, 'Photobooth '.$page['name'].' — SnapTechBooth'),
            'schema' => $schema,
        ]);
    }

    protected function region(string $slug, array $page): View
    {
        $url = $this->url($slug);
        $cities = collect(config('seo_pages.cities'))
            ->filter(fn ($c) => $c['province'] === $page['province']);

        $schema = [
            $this->business(),
            [
                '@type' => 'Service',
                '@id' => $url.'#service',
                'name' => 'Photobooth '.$page['name'],
                'serviceType' => 'Photobooth',
                'description' => $page['description'],
                'url' => $url,
                'provider' => ['@id' => $this->businessId()],
                'areaServed' => $cities->map(fn ($c) => ['@type' => 'City', 'name' => $c['name']])->values()->all(),
            ],
            $this->breadcrumb([
                ['Beranda', $this->url('')],
                ['Area Layanan', $this->url('area-layanan')],
                ['Photobooth '.$page['name'], $url],
            ]),
        ];

        return view('seo.region', [
            'slug' => $slug,
            'page' => $page,
            'cities' => $cities,
            'meta' => $this->meta($slug, $page['title'], $page['description'], 'Photobooth '.$page['name'].' — SnapTechBooth'),
            'schema' => $schema,
        ]);
    }

    public function areas(): View
    {
        $slug = 'area-layanan';
        $title = 'Area Layanan Photobooth dari Magetan: Jatim, Jateng, Jakarta & Bekasi | SnapTechBooth';
        $description = 'Daftar kota yang dilayani SnapTechBooth dari base di Magetan: Madiun, Ngawi, Ponorogo, Sragen, Karanganyar, Solo, Kediri, Surabaya, Semarang, sampai software untuk Jakarta dan Bekasi.';

        $schema = [
            $this->business(),
            $this->breadcrumb([
                ['Beranda', $this->url('')],
                ['Area Layanan', $this->url($slug)],
            ]),
        ];

        return view('seo.areas', [
            'slug' => $slug,
            'meta' => $this->meta($slug, $title, $description, 'Area layanan SnapTechBooth dari Magetan'),
            'schema' => $schema,
        ]);
    }

    // ── helpers ──────────────────────────────────────────────────────────

    protected function cityFaq(array $page, string $fullName): array
    {
        $tier = config('seo_pages.tiers.'.$page['tier']);

        $faq = [$page['faq']];

        if ($page['tier'] === 'jauh') {
            $faq[] = ["Apa yang perlu disiapkan cafe atau vendor di {$page['name']}?", 'Perangkat kiosk (Android atau Windows), kamera, dan printer foto. Kami bantu rekomendasi perangkat, lalu aktivasi dan pengaturan dilakukan dari jarak jauh.'];
            $faq[] = ['Bagaimana pembayaran dari pengunjung?', 'Pengunjung membayar lewat QRIS dinamis yang terverifikasi otomatis, dan setiap transaksi tercatat di dashboard.'];
        } elseif ($page['tier'] === 'base') {
            $faq[] = ['Jenis acara apa saja yang bisa dilayani?', 'Pernikahan, lamaran, wisuda, perpisahan sekolah, ulang tahun, gathering, bazar, sampai photobooth self-service permanen untuk cafe.'];
            $faq[] = ['Apakah tamu dapat file digital?', 'Ya. Setiap sesi punya QR code untuk mengunduh foto, GIF, dan video ke HP tanpa aplikasi tambahan.'];
        } else {
            $faq[] = ["Berapa lama perjalanan dari Magetan ke {$page['name']}?", "Perkiraannya {$page['drive']} ({$page['distance']}), tergantung rute dan lokasi acara. {$tier['note']}"];
            $faq[] = ["Apakah ada biaya transport ke {$page['name']}?", 'Biaya perjalanan menyesuaikan jarak dari Magetan dan dikonfirmasi di awal saat konsultasi, sehingga tidak ada biaya tambahan mendadak.'];
        }

        return $faq;
    }

    protected function meta(string $slug, string $title, string $description, string $imageAlt): array
    {
        return [
            'title' => $title,
            'description' => $description,
            'canonical' => $this->url($slug),
            'image' => $this->url('images/og/'.$slug.'.jpg'),
            'image_alt' => $imageAlt,
        ];
    }

    protected function url(string $path): string
    {
        return rtrim(config('seo_pages.business.url'), '/').'/'.ltrim($path, '/');
    }

    protected function businessId(): string
    {
        return $this->url('').'#organization';
    }

    protected function business(): array
    {
        $b = config('seo_pages.business');

        return [
            '@type' => 'LocalBusiness',
            '@id' => $this->businessId(),
            'name' => $b['name'],
            'url' => $this->url(''),
            'logo' => $this->url('icon-512.png'),
            'image' => $this->url('og-image.jpg'),
            'telephone' => $b['phone_schema'],
            'address' => [
                '@type' => 'PostalAddress',
                'addressLocality' => $b['base_city'],
                'addressRegion' => $b['base_region'],
                'addressCountry' => 'ID',
            ],
            'geo' => [
                '@type' => 'GeoCoordinates',
                'latitude' => $b['geo']['lat'],
                'longitude' => $b['geo']['lng'],
            ],
            'areaServed' => collect(config('seo_pages.cities'))
                ->map(fn ($c) => ['@type' => 'City', 'name' => $c['name']])
                ->values()->all(),
        ];
    }

    protected function breadcrumb(array $items): array
    {
        return [
            '@type' => 'BreadcrumbList',
            'itemListElement' => collect($items)->values()->map(fn ($item, $i) => [
                '@type' => 'ListItem',
                'position' => $i + 1,
                'name' => $item[0],
                'item' => $item[1],
            ])->all(),
        ];
    }

    protected function faqSchema(array $faq): array
    {
        return [
            '@type' => 'FAQPage',
            'mainEntity' => collect($faq)->map(fn ($qa) => [
                '@type' => 'Question',
                'name' => $qa[0],
                'acceptedAnswer' => ['@type' => 'Answer', 'text' => $qa[1]],
            ])->all(),
        ];
    }
}
