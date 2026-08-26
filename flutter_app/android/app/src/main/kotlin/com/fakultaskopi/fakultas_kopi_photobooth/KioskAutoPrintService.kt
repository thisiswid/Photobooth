package com.fakultaskopi.fakultas_kopi_photobooth

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * KioskAutoPrintService — Accessibility Service untuk auto-tap tombol Print
 * di PrintActivity (com.android.printspooler) sehingga cetak berjalan tanpa
 * interaksi user sama sekali.
 *
 * Flow:
 * 1. PrintManager.print() dipanggil dari Flutter → PrintActivity terbuka
 * 2. Service mendeteksi window PrintActivity
 * 3. Service mencari tombol "Print" / "Cetak" / "PRINT"
 * 4. Service auto-tap tombol → printer langsung cetak
 *
 * Aktivasi (sekali saja di tablet):
 * adb shell settings put secure enabled_accessibility_services \
 *   com.fakultaskopi.fakultas_kopi_photobooth/.KioskAutoPrintService
 * adb shell settings put secure accessibility_enabled 1
 */
class KioskAutoPrintService : AccessibilityService() {

    companion object {
        private const val TAG = "KioskAutoPrint"
        private const val PRINT_SPOOLER_PKG = "com.android.printspooler"

        // Delay sebelum tap (ms) — beri waktu UI PrintActivity render penuh
        private const val TAP_DELAY_MS = 800L

        // Singleton reference untuk cek status dari MainActivity
        @Volatile
        var instance: KioskAutoPrintService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }

    private val handler = Handler(Looper.getMainLooper())
    private var hasTappedForCurrentJob = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "✅ KioskAutoPrintService connected — auto-print aktif")

        // Konfigurasi ulang service via code (backup selain XML)
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
            packageNames = arrayOf(PRINT_SPOOLER_PKG)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return

        val pkg = event.packageName?.toString() ?: return
        if (pkg != PRINT_SPOOLER_PKG) return

        // Reset flag saat window baru PrintActivity terbuka
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            hasTappedForCurrentJob = false
            Log.d(TAG, "🖨️ PrintActivity window detected — scheduling auto-tap")
        }

        if (!hasTappedForCurrentJob) {
            // Delay agar UI sudah render sebelum mencari tombol
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({ tryTapPrintButton() }, TAP_DELAY_MS)
        }
    }

    private fun tryTapPrintButton() {
        if (hasTappedForCurrentJob) return

        val root = rootInActiveWindow ?: run {
            Log.w(TAG, "⚠️ rootInActiveWindow null — skip")
            return
        }

        // Cari tombol Print dengan berbagai label (EN/ID/Epson)
        val printLabels = listOf(
            "Print", "PRINT", "Cetak", "CETAK",
            "print", "cetak", "طباعة", "Imprimir"
        )

        val printNode = findButtonByText(root, printLabels)
            ?: findButtonByViewId(root, "com.android.printspooler:id/print_button")
            ?: findButtonByViewId(root, "com.android.printspooler:id/printButton")

        if (printNode != null) {
            hasTappedForCurrentJob = true
            val tapped = printNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.i(TAG, if (tapped) "✅ Auto-tap Print berhasil!" else "❌ Auto-tap Print gagal")
            printNode.recycle()
        } else {
            Log.w(TAG, "⚠️ Tombol Print tidak ditemukan — retry dalam 500ms")
            // Retry sekali lagi kalau UI belum siap
            handler.postDelayed({ retryTapPrintButton() }, 500L)
        }

        root.recycle()
    }

    private fun retryTapPrintButton() {
        if (hasTappedForCurrentJob) return

        val root = rootInActiveWindow ?: return

        val printLabels = listOf(
            "Print", "PRINT", "Cetak", "CETAK",
            "print", "cetak"
        )

        val printNode = findButtonByText(root, printLabels)
            ?: findButtonByViewId(root, "com.android.printspooler:id/print_button")

        if (printNode != null) {
            hasTappedForCurrentJob = true
            val tapped = printNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.i(TAG, if (tapped) "✅ Auto-tap Print (retry) berhasil!" else "❌ Auto-tap Print (retry) gagal")
            printNode.recycle()
        } else {
            Log.w(TAG, "❌ Tombol Print tidak ditemukan setelah retry — PrintActivity mungkin belum siap")
        }

        root.recycle()
    }

    /**
     * Cari node bertipe Button dengan text yang cocok (case-insensitive)
     */
    private fun findButtonByText(
        root: AccessibilityNodeInfo,
        labels: List<String>
    ): AccessibilityNodeInfo? {
        for (label in labels) {
            val nodes = root.findAccessibilityNodeInfosByText(label)
            for (node in nodes) {
                if (node.isClickable && node.isEnabled) {
                    return node
                }
                node.recycle()
            }
        }
        return null
    }

    /**
     * Cari node berdasarkan viewId (resource-id)
     */
    private fun findButtonByViewId(
        root: AccessibilityNodeInfo,
        viewId: String
    ): AccessibilityNodeInfo? {
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        return nodes.firstOrNull { it.isClickable && it.isEnabled }
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
