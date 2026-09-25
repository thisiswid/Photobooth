<?php

namespace App\Support;

class AdminGuide
{
    public static function tour(string $routeName): array
    {
        $parts = explode('.', $routeName);
        $topic = in_array('resources', $parts, true) ? ($parts[3] ?? '') : ($parts[3] ?? 'dashboard');
        $mode = in_array('resources', $parts, true) ? end($parts) : 'index';
        $guide = config("photobooth-guide.admin.{$topic}");
        $step = static fn (string $title, string $body, ?string $target = null): array => compact('title', 'body', 'target');

        if ($topic === 'dokumentasi') {
            $steps = [
                $step('Pusat dokumentasi', 'Panduan admin dan aplikasi kiosk tersedia di satu tempat. Pilih topik dari daftar isi.', '#guide-contents'),
                $step('Panduan admin', 'Ikuti langkah kerja setiap menu admin. Tombol ? di setiap halaman dapat mengulang tur kapan saja.', '#guide-admin'),
                $step('Panduan aplikasi', 'Pelajari alur aktivasi, pengaturan mesin, pembayaran, foto, hingga unduhan.', '#guide-app'),
            ];
        } else {
            $guide ??= ['title' => 'Panduan halaman', 'intro' => 'Pelajari bagian utama halaman ini.'];
            $steps = [$step($guide['title'], $guide['intro'], '.fi-header')];
            if ($topic === 'dashboard') {
                $steps[] = $step('Menu admin', 'Pilih menu untuk mengatur konten, perangkat, transaksi, dan operasional cafe.', '.fi-sidebar');
                $steps[] = $step('Ringkasan & aktivitas', implode(' ', $guide['steps']), '.fi-wi');
            } elseif (in_array($mode, ['create', 'edit'], true)) {
                foreach (config("photobooth-guide-forms.{$topic}", []) as [$field, $title, $body]) {
                    $steps[] = $step($title, $body, '.fi-sc-form .fi-fo-field:has([id$=".'.$field.'"], [for$=".'.$field.'"])');
                }
                $steps[] = $step('Periksa & simpan', 'Periksa isian wajib dan pesan validasi. Gunakan tombol simpan untuk menerapkan perubahan atau batal untuk kembali.', '.fi-sc-form .fi-sc-actions');
            } elseif ($mode === 'view') {
                $steps[] = $step('Detail data', implode(' ', $guide['steps'] ?? []), '.fi-page-content');
                $steps[] = $step('Aksi yang tersedia', 'Gunakan aksi pada halaman sesuai kebutuhan setelah memeriksa detail data.', '.fi-header-actions-ctn');
            } else {
                foreach ($guide['steps'] ?? [] as $i => $body) {
                    $steps[] = $step('Langkah '.($i + 1), $body, $i === 0 ? '.fi-header-actions-ctn, .fi-ta' : '.fi-ta');
                }
                $steps[] = $step('Cari data', 'Ketik kata kunci untuk menemukan data pada daftar ini.', '.fi-ta-search-field');
                $steps[] = $step('Filter daftar', 'Gunakan filter untuk mempersempit data yang ditampilkan.', '.fi-ta-filters-trigger-action-ctn');
            }
            $steps[] = $step('Bantuan selalu tersedia', 'Klik tombol ? untuk mengulang tur halaman ini, atau buka dokumentasi untuk panduan admin dan aplikasi.', '#photobooth-help');
        }

        return ['key' => "{$topic}.{$mode}", 'steps' => $steps];
    }
}
