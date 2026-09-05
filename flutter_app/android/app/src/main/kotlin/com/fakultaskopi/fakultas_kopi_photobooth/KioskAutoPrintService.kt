package com.fakultaskopi.fakultas_kopi_photobooth

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * KioskAutoPrintService — menekan tombol Print di dialog cetak Android supaya
 * cetak berjalan tanpa sentuhan operator.
 *
 * Ini adalah jalur FALLBACK. Jalur utama adalah IPP langsung (silent, tanpa
 * dialog sama sekali). Service ini dipakai saat IPP tidak tersedia — misalnya
 * printer hanya tersambung USB, karena Epson L8050 tidak mengekspos IPP-over-USB
 * (hasil probe: interface printer raw 7/1/2 saja).
 *
 * Perbedaan dari versi sebelumnya:
 *
 * 1. TIDAK lagi dikunci ke package `com.android.printspooler`. Banyak ROM OEM
 *    memakai package dialog cetak yang berbeda; begitu tidak cocok, service
 *    tidak pernah menerima event dan cetak berhenti diam-diam.
 *
 * 2. Dipakai sistem "armed": MainActivity memanggil [arm] tepat sebelum
 *    PrintManager.print(). Di luar jendela waktu itu semua event diabaikan pada
 *    baris pertama, jadi tidak boros meski mendengarkan semua package.
 *
 * 3. Pencarian tombol tidak lagi sekali-tembak dengan delay tetap 800 ms.
 *    Sekarang polling berkala sampai [ARM_WINDOW_MS] habis, karena waktu render
 *    dialog berbeda-beda tergantung ROM, beban CPU, dan kecepatan Print Service
 *    menemukan printer.
 *
 * 4. Pencocokan tombol berlapis: resource-id → teks → content-description →
 *    pemindaian node clickable yang labelnya mengandung kata cetak.
 */
class KioskAutoPrintService : AccessibilityService() {

    companion object {
        private const val TAG = "KioskAutoPrint"

        /** Berapa lama service aktif mencari tombol setelah di-arm. */
        private const val ARM_WINDOW_MS = 20_000L

        /** Jeda antar percobaan pencarian tombol. */
        private const val POLL_INTERVAL_MS = 350L

        /** Jeda pertama — beri dialog waktu render awal. */
        private const val FIRST_DELAY_MS = 500L

        @Volatile
        var instance: KioskAutoPrintService? = null
            private set

        @Volatile
        private var armedUntilMs: Long = 0L

        @Volatile
        private var tappedForThisArm: Boolean = false

        /** Diagnostik untuk UI: hasil percobaan terakhir. */
        @Volatile
        var lastResult: String = "belum pernah dijalankan"

        @Volatile
        var lastSpoolerPackage: String = ""

        fun isRunning(): Boolean = instance != null

        /**
         * Buka jendela waktu di mana service boleh menekan tombol Print.
         * Dipanggil MainActivity tepat sebelum PrintManager.print().
         */
        fun arm() {
            armedUntilMs = SystemClock.uptimeMillis() + ARM_WINDOW_MS
            tappedForThisArm = false
            lastResult = "menunggu dialog cetak muncul..."
            Log.i(TAG, "🎯 Armed ${ARM_WINDOW_MS}ms — siap menekan tombol Print")
            instance?.schedulePolling(FIRST_DELAY_MS)
        }

        /** Tutup jendela waktu (dipakai setelah berhasil menekan). */
        fun disarm() {
            armedUntilMs = 0L
        }

        private fun isArmed(): Boolean =
            SystemClock.uptimeMillis() < armedUntilMs && !tappedForThisArm
    }

    private val handler = Handler(Looper.getMainLooper())

    /** resource-id tombol Print di berbagai ROM. */
    private val buttonIds = listOf(
        "com.android.printspooler:id/print_button",
        "com.android.printspooler:id/printButton",
        "android:id/button1"
    )

    /** Label tombol Print dalam berbagai bahasa. */
    private val printLabels = listOf(
        "Print", "PRINT", "print",
        "Cetak", "CETAK", "cetak",
        "Imprimir", "Drucken", "Imprimer", "印刷", "打印", "인쇄", "طباعة"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "✅ KioskAutoPrintService connected")

        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
            packageNames = null // dengarkan semua — lihat catatan di kelas
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Baris pertama: di luar jendela armed, tidak melakukan apa pun.
        if (!isArmed()) return
        event ?: return

        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return // abaikan window aplikasi sendiri

        schedulePolling(0L)
    }

    fun schedulePolling(initialDelay: Long) {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ pollForPrintButton() }, initialDelay)
    }

    private fun pollForPrintButton() {
        if (!isArmed()) {
            if (!tappedForThisArm && armedUntilMs != 0L) {
                lastResult = "❌ tombol Print tidak ditemukan sampai batas waktu " +
                        "(${ARM_WINDOW_MS / 1000}s). Dialog cetak mungkin tidak terbuka, " +
                        "atau printer tidak ditemukan Print Service."
                Log.w(TAG, lastResult)
                armedUntilMs = 0L
            }
            return
        }

        // Kumpulkan SEMUA root window, bukan hanya yang aktif.
        //
        // Aplikasi menampilkan lapisan penutup di atas dialog cetak supaya
        // pelanggan tidak melihatnya. Lapisan itu dipasang NOT_FOCUSABLE agar
        // rootInActiveWindow tetap menunjuk ke dialog, tapi perilaku itu bisa
        // berbeda antar ROM. Menyapu seluruh window membuat pencarian tombol
        // tetap berhasil apa pun yang dianggap "aktif" oleh sistem.
        val roots = mutableListOf<AccessibilityNodeInfo>()
        rootInActiveWindow?.let { roots.add(it) }
        try {
            for (w in windows) {
                val r = w.root ?: continue
                if (roots.none { it == r }) roots.add(r)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Tidak bisa membaca daftar window: ${e.message}")
        }

        if (roots.isEmpty()) {
            handler.postDelayed({ pollForPrintButton() }, POLL_INTERVAL_MS)
            return
        }

        try {
            for (root in roots) {
                val pkg = root.packageName?.toString() ?: "?"
                // Lewati window milik aplikasi sendiri, termasuk lapisan penutup.
                if (pkg == packageName) continue

                val node = findPrintButton(root) ?: continue

                val clicked = clickNodeOrAncestor(node)
                if (clicked) {
                    tappedForThisArm = true
                    disarm()
                    lastSpoolerPackage = pkg
                    lastResult = "✅ tombol Print ditekan otomatis (dialog: $pkg)"
                    Log.i(TAG, lastResult)
                    handler.removeCallbacksAndMessages(null)
                    return
                }
                Log.w(TAG, "Tombol ditemukan di $pkg tapi klik ditolak — coba lagi")
            }
        } catch (e: Exception) {
            Log.e(TAG, "pollForPrintButton error: ${e.message}")
        }

        handler.postDelayed({ pollForPrintButton() }, POLL_INTERVAL_MS)
    }

    // ─── Pencarian tombol berlapis ────────────────────────────────────────────

    private fun findPrintButton(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // 1. resource-id — paling andal bila cocok
        for (id in buttonIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            val hit = nodes.firstOrNull { it.isEnabled }
            if (hit != null) return hit
        }

        // 2. teks persis
        for (label in printLabels) {
            val nodes = root.findAccessibilityNodeInfosByText(label)
            val hit = nodes.firstOrNull { it.isEnabled && looksLikePrintButton(it) }
            if (hit != null) return hit
        }

        // 3. sapu seluruh pohon: content-description atau teks yang mengandung
        //    kata cetak, pada node yang bisa diklik
        return scanTree(root, 0)
    }

    private fun scanTree(node: AccessibilityNodeInfo?, depth: Int): AccessibilityNodeInfo? {
        if (node == null || depth > 25) return null

        if (node.isEnabled && looksLikePrintButton(node)) return node

        for (i in 0 until node.childCount) {
            val hit = scanTree(node.getChild(i), depth + 1)
            if (hit != null) return hit
        }
        return null
    }

    private fun looksLikePrintButton(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.trim().orEmpty()
        val desc = node.contentDescription?.toString()?.trim().orEmpty()
        val haystack = "$text $desc".lowercase()
        if (haystack.isBlank()) return false

        // Hindari salah tekan "Print preview", "Printer", "Print settings".
        val negative = listOf("preview", "pratinjau", "setting", "pengaturan", "pilih printer", "select printer")
        if (negative.any { haystack.contains(it) }) return false

        val positive = printLabels.any { haystack.contains(it.lowercase()) }
        if (!positive) return false

        return node.isClickable || hasClickableAncestor(node)
    }

    private fun hasClickableAncestor(node: AccessibilityNodeInfo): Boolean {
        var p = node.parent
        var hops = 0
        while (p != null && hops < 5) {
            if (p.isClickable && p.isEnabled) return true
            p = p.parent
            hops++
        }
        return false
    }

    /**
     * Klik node; bila node itu sendiri tidak clickable (umum untuk TextView di
     * dalam Button), naik ke leluhur terdekat yang clickable.
     */
    private fun clickNodeOrAncestor(node: AccessibilityNodeInfo): Boolean {
        if (node.isClickable && node.isEnabled) {
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true
        }
        var p = node.parent
        var hops = 0
        while (p != null && hops < 5) {
            if (p.isClickable && p.isEnabled) {
                if (p.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true
            }
            p = p.parent
            hops++
        }
        return false
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ KioskAutoPrintService interrupted")
        handler.removeCallbacksAndMessages(null)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        handler.removeCallbacksAndMessages(null)
        Log.i(TAG, "KioskAutoPrintService destroyed")
    }
}
