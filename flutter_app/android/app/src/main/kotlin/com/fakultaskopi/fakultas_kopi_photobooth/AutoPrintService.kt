package com.fakultaskopi.fakultas_kopi_photobooth

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * ??? AutoPrintService — Android Accessibility Service untuk Kiosk Mode.
 *
 * Menunggu jeda ~1.5 detik agar PrintSpooler selesai menghubungkan printer Epson
 * dan merender dokumen, lalu menekan tombol "Print" otomatis.
 */
class AutoPrintService : AccessibilityService() {

    private val TAG = "AutoPrintService"
    private var lastClickTime = 0L
    private val handler = Handler(Looper.getMainLooper())
    private var isSearching = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: return
        if (!pkg.contains("printspooler", ignoreCase = true)) return

        val now = System.currentTimeMillis()
        if (now - lastClickTime < 3000) return // Debounce 3 detik

        if (isSearching) return
        isSearching = true

        Log.d(TAG, "??? PrintSpooler terdeteksi, memberi jeda 1.5 detik agar Epson L8050 siap...")

        // Jeda 1.5 detik agar PrintSpooler selesai inisialisasi printer & kertas
        handler.postDelayed({
            attemptClick()
            // Fallback coba lagi di 2.5 detik jika printer butuh waktu sedikit lebih lama
            handler.postDelayed({ attemptClick() }, 1000)
            handler.postDelayed({
                isSearching = false
            }, 3000)
        }, 1500)
    }

    private fun attemptClick() {
        val now = System.currentTimeMillis()
        if (now - lastClickTime < 3000) return

        val rootNode = rootInActiveWindow ?: return
        try {
            if (findAndClickPrintButton(rootNode)) {
                lastClickTime = System.currentTimeMillis()
                Log.i(TAG, "? Tombol Print berhasil diklik otomatis oleh Kiosk AutoPrintService!")
            } else {
                Log.w(TAG, "?? Tombol Print belum siap di-klik.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "? Error saat menekan tombol print: ${e.message}")
        }
    }

    private fun findAndClickPrintButton(node: AccessibilityNodeInfo): Boolean {
        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""

        val isPrintButton = viewId.contains("print_button") ||
                viewId.contains("action_print") ||
                viewId.contains("button_print") ||
                text == "print" || text == "cetak" ||
                desc == "print" || desc == "cetak" ||
                desc.contains("print") || desc.contains("cetak")

        if (isPrintButton && node.isEnabled) {
            if (node.isClickable) {
                val success = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (success) return true
            }
            var parent = node.parent
            while (parent != null) {
                if (parent.isClickable && parent.isEnabled) {
                    val success = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (success) return true
                }
                parent = parent.parent
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (findAndClickPrintButton(child)) {
                return true
            }
        }
        return false
    }

    override fun onInterrupt() {
        Log.d(TAG, "AutoPrintService onInterrupt")
    }
}

