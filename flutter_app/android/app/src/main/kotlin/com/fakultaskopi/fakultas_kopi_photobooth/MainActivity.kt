package com.fakultaskopi.fakultas_kopi_photobooth

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.content.Intent
import android.graphics.BitmapFactory
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.*
import android.print.PrintAttributes.*
import android.print.pdf.PrintedPdfDocument
import android.graphics.pdf.PdfDocument
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream
import java.io.IOException
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fakultaskopi.photobooth/printer"
    private val SONY_CAMERA_CHANNEL = "com.fakultaskopi.photobooth/sony_camera"
    private val TAG = "PhotoboothPrinter"

    private lateinit var sonyCameraManager: SonyPtpCameraManager

    /** Lapisan penutup dialog cetak. Null bila sedang tidak tampil. */
    private var printCoverView: View? = null
    private val coverHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var coverTapCount = 0
    /** Semua I/O USB/PTP dijalankan di sini — JANGAN di thread platform. */
    private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sonyCameraManager = SonyPtpCameraManager(this)

        // ── 1. SONY ZV-E10 USB PTP CAMERA CHANNEL ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SONY_CAMERA_CHANNEL).setMethodCallHandler { call, result ->
            // PENTING: operasi USB/PTP di bawah melakukan control & bulk transfer
            // yang BLOKIR (device reset, clear-halt, timeout beberapa detik).
            // Menjalankannya di thread platform membekukan UI — terlihat sebagai
            // "Slow dispatch took 13309ms main" / "Skipped 1942 frames".
            // Karena itu semuanya dipindah ke Dispatchers.IO.
            when (call.method) {
                "getSonyCameraStatus" -> {
                    ioScope.launch {
                        val status = sonyCameraManager.getCameraStatus()
                        withContext(Dispatchers.Main) { result.success(status) }
                    }
                }
                "requestSonyPermission" -> {
                    sonyCameraManager.requestPermission { granted ->
                        result.success(granted)
                    }
                }
                // Izin USB untuk HDMI capture card (jalur live preview UVC)
                "requestUvcPermission" -> {
                    sonyCameraManager.requestUvcPermission { granted ->
                        result.success(granted)
                    }
                }
                "connectSonyCamera" -> {
                    ioScope.launch {
                        val opened = sonyCameraManager.openConnection()
                        val remoteReady = sonyCameraManager.isRemoteControlReady()
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                // "success" hanya true bila kamera benar-benar
                                // menerima perintah PC Remote. USB ter-claim saja
                                // tidak cukup — dulu ini dilaporkan sukses padahal
                                // handshake SDIO gagal, sehingga setiap shutter
                                // membuang waktu lalu gagal.
                                "success" to (opened && remoteReady),
                                "usbClaimed" to opened,
                                "remoteReady" to remoteReady,
                                "message" to when {
                                    !opened -> "Gagal membuka koneksi USB Sony."
                                    !remoteReady -> "USB tersambung tapi kamera menolak PC Remote. " +
                                        "Di kamera: MENU > Setup > USB > USB Connection = PC Remote, " +
                                        "dan MENU > Network > PC Remote Function > PC Remote = ON."
                                    else -> "Sony ZV-E10 terhubung via USB PTP"
                                }
                            ))
                        }
                    }
                }
                "disconnectSonyCamera" -> {
                    ioScope.launch {
                        sonyCameraManager.closeConnection()
                        withContext(Dispatchers.Main) { result.success(true) }
                    }
                }
                "captureSonyPhoto" -> {
                    ioScope.launch {
                        val captureResult = sonyCameraManager.capturePhoto()
                        withContext(Dispatchers.Main) { result.success(captureResult) }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── 2. PRINTER CHANNEL (UNTOUCHED) ───────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "printPhoto" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val jobName = call.argument<String>("jobName") ?: "Photobooth_Print"
                    val borderless = call.argument<Boolean>("borderless") ?: true
                    val quality = call.argument<String>("quality") ?: "Standard"
                    val marginHoriz = call.argument<Double>("marginHorizontal") ?: 0.0
                    val marginVert = call.argument<Double>("marginVertical") ?: 0.0
                    val marginUnit = call.argument<String>("marginUnit") ?: "mm"
                    val coverDialog = call.argument<Boolean>("coverDialog") ?: true
                    val coverText = call.argument<String>("coverText") ?: "Mencetak foto Anda..."
                    if (imageBytes != null) {
                        if (coverDialog) showPrintCover(coverText)
                        printPhoto(imageBytes, jobName, borderless, quality, marginHoriz, marginVert, marginUnit, result)
                    } else {
                        result.error("INVALID_ARGS", "imageBytes is null", null)
                    }
                }
                "printPdf" -> {
                    val pdfBytes = call.argument<ByteArray>("pdfBytes")
                    val jobName = call.argument<String>("jobName") ?: "Photobooth_Print"
                    val borderless = call.argument<Boolean>("borderless") ?: true
                    val quality = call.argument<String>("quality") ?: "Standard"
                    val marginHoriz = call.argument<Double>("marginHorizontal") ?: 0.0
                    val marginVert = call.argument<Double>("marginVertical") ?: 0.0
                    val marginUnit = call.argument<String>("marginUnit") ?: "mm"
                    val coverDialog = call.argument<Boolean>("coverDialog") ?: true
                    val coverText = call.argument<String>("coverText") ?: "Mencetak foto Anda..."
                    if (pdfBytes != null) {
                        if (coverDialog) showPrintCover(coverText)
                        printPdf(pdfBytes, jobName, borderless, quality, marginHoriz, marginVert, marginUnit, result)
                    } else {
                        result.error("INVALID_ARGS", "pdfBytes is null", null)
                    }
                }
                "detectUsbPrinter" -> detectUsbPrinter(result)
                "probeUsbPrinterInterfaces" -> probeUsbPrinterInterfaces(result)
                "getNetworkDiagnostics" -> result.success(networkDiagnostics())
                "bindProcessToWifi" -> result.success(bindProcessToWifi())
                "unbindProcessNetwork" -> result.success(unbindProcessNetwork())
                "requestUsbPermission" -> result.success(false) // USB permission via dialog tidak diperlukan — PrintManager handle via Epson Print Service
                "isAutoPrintServiceEnabled" -> result.success(isEpsonPrintServiceEnabled())
                "getAutoPrintHelperStatus" -> result.success(autoPrintHelperStatus())
                "canDrawOverlays" -> result.success(canDrawOverlaysCompat())
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "hidePrintCover" -> {
                    hidePrintCover()
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "getPrinterStatus" -> result.success(getPrinterStatus())
                else -> result.notImplemented()
            }
        }
    }

    // ─── PENUTUP DIALOG CETAK ────────────────────────────────────────────────
    //
    // Android tidak mengizinkan aplikasi mencetak tanpa membuka print spooler.
    // Yang bisa dilakukan adalah menutupi spooler itu dengan lapisan milik
    // aplikasi sendiri, sehingga pelanggan hanya melihat layar kiosk.
    // Dialognya tetap ada di baliknya dan tetap ditekan KioskAutoPrintService —
    // penekanan lewat Accessibility tidak memakai sentuhan layar, jadi tidak
    // terhalang lapisan ini.
    //
    // PENGAMAN — lapisan yang menyangkut akan mengunci tablet secara visual,
    // jadi ada tiga jalan keluar yang saling menutupi:
    //   1. batas waktu keras COVER_TIMEOUT_MS
    //   2. dilepas saat print job selesai (onFinish) atau activity berhenti
    //   3. ketuk 3x pada lapisan untuk melepas paksa (jalan keluar operator)

    companion object {
        private const val COVER_TIMEOUT_MS = 25_000L
        private const val OVERLAY_REQUEST_CODE = 4711
    }

    private fun canDrawOverlaysCompat(): Boolean {
        return if (Build.VERSION.SDK_INT >= 23) Settings.canDrawOverlays(this) else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < 23) return
        try {
            startActivityForResult(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ),
                OVERLAY_REQUEST_CODE
            )
        } catch (e: Exception) {
            Log.e(TAG, "requestOverlayPermission error: ${e.message}")
        }
    }

    private fun buildCoverView(message: String): View {
        val root = FrameLayout(this)
        root.setBackgroundColor(Color.parseColor("#1A0F0A"))
        root.isClickable = true

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val spinner = ProgressBar(this).apply {
            isIndeterminate = true
        }

        val label = TextView(this).apply {
            text = message
            setTextColor(Color.parseColor("#F5E6D3"))
            textSize = 20f
            gravity = Gravity.CENTER
            setPadding(0, 48, 0, 0)
        }

        column.addView(
            spinner,
            LinearLayout.LayoutParams(120, 120).apply { gravity = Gravity.CENTER }
        )
        column.addView(label)

        root.addView(
            column,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        )

        // Jalan keluar operator: ketuk 3x untuk melepas paksa.
        root.setOnClickListener {
            coverTapCount++
            if (coverTapCount >= 3) {
                Log.w(TAG, "Penutup dilepas paksa oleh operator (ketuk 3x)")
                hidePrintCover()
            }
        }

        return root
    }

    /** Tampilkan lapisan penutup. Aman dipanggil berulang. */
    private fun showPrintCover(message: String) {
        runOnUiThread {
            if (printCoverView != null) return@runOnUiThread
            if (!canDrawOverlaysCompat()) {
                Log.w(TAG, "⚠️ Izin overlay belum diberikan — dialog cetak akan terlihat")
                return@runOnUiThread
            }
            try {
                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val view = buildCoverView(message)
                coverTapCount = 0

                val type = if (Build.VERSION.SDK_INT >= 26) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    type,
                    // NOT_FOCUSABLE penting: tanpa ini lapisan kita menjadi window
                    // aktif, dan rootInActiveWindow milik Accessibility Service akan
                    // menunjuk ke lapisan ini — bukan ke dialog cetak — sehingga
                    // tombol Print tidak akan pernah ditemukan.
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.OPAQUE
                )

                wm.addView(view, params)
                printCoverView = view
                Log.i(TAG, "🪟 Penutup dialog cetak ditampilkan")

                coverHandler.removeCallbacksAndMessages(null)
                coverHandler.postDelayed({
                    Log.w(TAG, "Penutup dilepas otomatis — batas waktu tercapai")
                    hidePrintCover()
                }, COVER_TIMEOUT_MS)
            } catch (e: Exception) {
                Log.e(TAG, "showPrintCover error: ${e.message}")
                printCoverView = null
            }
        }
    }

    /** Lepas lapisan penutup. Aman dipanggil berkali-kali. */
    private fun hidePrintCover() {
        runOnUiThread {
            coverHandler.removeCallbacksAndMessages(null)
            val view = printCoverView ?: return@runOnUiThread
            printCoverView = null
            try {
                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(view)
                Log.i(TAG, "🪟 Penutup dialog cetak dilepas")
            } catch (e: Exception) {
                Log.e(TAG, "hidePrintCover error: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        hidePrintCover()
        coverHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // ─── NETWORK BINDING & DIAGNOSTICS ───────────────────────────────────────
    //
    // Masalah klasik Android: bila Wi-Fi tersambung ke jaringan TANPA internet
    // (router printer, hotspot printer, Wi-Fi Direct), sistem menandainya
    // "no internet" dan mengarahkan trafik aplikasi ke jaringan lain (seluler,
    // atau tidak ke mana-mana). Akibatnya `Socket.connect` dari Dart ke IP
    // printer di LAN GAGAL, padahal printernya jelas ada dan sejaring.
    //
    // Solusinya mengikat proses ke Network Wi-Fi secara eksplisit lewat
    // ConnectivityManager.bindProcessToNetwork() sebelum bicara ke printer.

    private fun transportsOf(caps: NetworkCapabilities?): List<String> {
        if (caps == null) return emptyList()
        val t = mutableListOf<String>()
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) t.add("WIFI")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) t.add("CELLULAR")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) t.add("ETHERNET")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) t.add("VPN")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) t.add("BLUETOOTH")
        if (Build.VERSION.SDK_INT >= 31 &&
            caps.hasTransport(NetworkCapabilities.TRANSPORT_USB)) t.add("USB")
        return t
    }

    /**
     * Laporan seluruh Network yang dikenal sistem: transport, apakah aktif,
     * apakah tervalidasi (punya internet), interface, dan alamat IP-nya.
     */
    private fun networkDiagnostics(): Map<String, Any?> {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val active = cm.activeNetwork

            val sb = StringBuilder()
            var wifiPresent = false
            var wifiIsActive = false
            var wifiValidated = false
            val wifiAddresses = mutableListOf<String>()

            @Suppress("DEPRECATION")
            val networks = cm.allNetworks

            val list = networks.map { n ->
                val caps = cm.getNetworkCapabilities(n)
                val lp = cm.getLinkProperties(n)
                val transports = transportsOf(caps)
                val isActive = (n == active)
                val validated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ?: false
                val hasInternet = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false
                val addresses = lp?.linkAddresses?.mapNotNull { it.address.hostAddress } ?: emptyList()
                val ifName = lp?.interfaceName ?: ""

                if (transports.contains("WIFI")) {
                    wifiPresent = true
                    if (isActive) wifiIsActive = true
                    if (validated) wifiValidated = true
                    wifiAddresses.addAll(addresses.filter { !it.contains(":") })
                }

                sb.append(if (isActive) "★ " else "  ")
                sb.append(transports.joinToString("+").ifEmpty { "UNKNOWN" })
                sb.append("  if=$ifName")
                sb.append("  internet=$hasInternet validated=$validated\n")
                sb.append("     addr: ${addresses.joinToString(", ").ifEmpty { "(none)" }}\n")
                lp?.routes?.take(4)?.forEach { sb.append("     route: $it\n") }

                mapOf(
                    "isActive" to isActive,
                    "transports" to transports,
                    "hasInternet" to hasInternet,
                    "validated" to validated,
                    "interfaceName" to ifName,
                    "addresses" to addresses
                )
            }

            // Diagnosa: Wi-Fi ada tapi BUKAN jaringan aktif = trafik app tidak
            // lewat Wi-Fi, sehingga printer di LAN tidak akan terjangkau.
            val warning = when {
                !wifiPresent -> "Tablet TIDAK tersambung ke Wi-Fi sama sekali. " +
                    "Printer jaringan mustahil dijangkau."
                !wifiIsActive -> "Wi-Fi tersambung TAPI bukan jaringan aktif — trafik aplikasi " +
                    "dialihkan ke jaringan lain (biasanya karena Wi-Fi dianggap 'tanpa internet'). " +
                    "Inilah sebabnya socket ke IP printer gagal. Aktifkan 'Ikat Proses ke Wi-Fi'."
                !wifiValidated -> "Wi-Fi aktif tapi ditandai tanpa internet. Socket ke LAN " +
                    "biasanya masih bisa, tapi Android dapat memindahkan trafik sewaktu-waktu. " +
                    "Sebaiknya 'Ikat Proses ke Wi-Fi' tetap dinyalakan."
                else -> ""
            }

            mapOf(
                "success" to true,
                "wifiPresent" to wifiPresent,
                "wifiIsActive" to wifiIsActive,
                "wifiValidated" to wifiValidated,
                "wifiAddresses" to wifiAddresses,
                "networkCount" to list.size,
                "warning" to warning,
                "rawSummary" to sb.toString().trimEnd(),
                "networks" to list
            )
        } catch (e: Exception) {
            Log.e(TAG, "networkDiagnostics error: ${e.message}")
            mapOf(
                "success" to false,
                "wifiPresent" to false,
                "wifiIsActive" to false,
                "wifiValidated" to false,
                "wifiAddresses" to emptyList<String>(),
                "networkCount" to 0,
                "warning" to "Gagal membaca status jaringan: ${e.message}",
                "rawSummary" to "",
                "networks" to emptyList<Any>()
            )
        }
    }

    /**
     * Ikat SELURUH proses aplikasi ke Network Wi-Fi, supaya Socket.connect dari
     * Dart benar-benar keluar lewat Wi-Fi dan bisa menyentuh printer di LAN.
     *
     * Wajib dipasangkan dengan unbindProcessNetwork() setelah selesai, kalau
     * tidak trafik backend/Pakasir ikut terkunci di Wi-Fi tanpa internet.
     */
    private fun bindProcessToWifi(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 23) {
            return mapOf("success" to false, "message" to "Butuh Android 6.0+ (API 23).")
        }
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            @Suppress("DEPRECATION")
            val wifi = cm.allNetworks.firstOrNull {
                cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            if (wifi == null) {
                return mapOf("success" to false, "message" to "Tidak ada Network Wi-Fi yang bisa diikat.")
            }
            val ok = cm.bindProcessToNetwork(wifi)
            Log.i(TAG, "🔗 bindProcessToNetwork(WIFI) = $ok")
            mapOf("success" to ok, "message" to if (ok) "Proses diikat ke Wi-Fi." else "Sistem menolak binding.")
        } catch (e: Exception) {
            Log.e(TAG, "bindProcessToWifi error: ${e.message}")
            mapOf("success" to false, "message" to "Error binding: ${e.message}")
        }
    }

    /** Lepas ikatan proses, kembalikan routing ke default sistem. */
    private fun unbindProcessNetwork(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return false
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.bindProcessToNetwork(null)
            Log.i(TAG, "🔗 bindProcessToNetwork(null) — routing kembali ke default")
            true
        } catch (e: Exception) {
            Log.e(TAG, "unbindProcessNetwork error: ${e.message}")
            false
        }
    }

    // ─── USB DESCRIPTOR PROBE (Tahap 1 — diagnosa jalur silent print) ────────

    /** Label human-readable untuk USB interface class. */
    private fun usbClassLabel(cls: Int): String = when (cls) {
        0    -> "Per-Interface (0x00)"
        1    -> "Audio (0x01)"
        2    -> "CDC Control (0x02)"
        3    -> "HID (0x03)"
        6    -> "Still Image / PTP (0x06)"
        7    -> "Printer (0x07)"
        8    -> "Mass Storage (0x08)"
        9    -> "Hub (0x09)"
        10   -> "CDC Data (0x0A)"
        14   -> "Video / UVC (0x0E)"
        255  -> "Vendor Specific (0xFF)"
        else -> "Unknown (0x%02X)".format(cls)
    }

    /**
     * Label protokol khusus untuk interface class 7 (Printer).
     * Protocol 4 = IPP-over-USB → jalur silent print tanpa PrintManager.
     */
    private fun printerProtocolLabel(cls: Int, sub: Int, proto: Int): String {
        if (cls != 7) return "-"
        return when {
            sub == 1 && proto == 1 -> "Unidirectional (7/1/1)"
            sub == 1 && proto == 2 -> "Bidirectional (7/1/2)"
            sub == 1 && proto == 3 -> "IEEE 1284.4 (7/1/3)"
            sub == 1 && proto == 4 -> "IPP-over-USB (7/1/4) ✅"
            else                   -> "Printer ($cls/$sub/$proto)"
        }
    }

    private fun endpointTypeLabel(type: Int): String = when (type) {
        UsbConstants.USB_ENDPOINT_XFER_CONTROL -> "CONTROL"
        UsbConstants.USB_ENDPOINT_XFER_ISOC    -> "ISOC"
        UsbConstants.USB_ENDPOINT_XFER_BULK    -> "BULK"
        UsbConstants.USB_ENDPOINT_XFER_INT     -> "INTERRUPT"
        else -> "UNKNOWN"
    }

    /**
     * Enumerasi seluruh USB interface descriptor dari perangkat yang tersambung.
     *
     * TIDAK butuh USB permission — descriptor bisa dibaca tanpa openDevice().
     * Tujuannya menentukan jalur silent print yang tersedia untuk Epson L8050:
     *
     *   - Ada interface 7/1/4  → IPP-over-USB  → kirim IPP Print-Job via bulk EP (SILENT)
     *   - Hanya 7/1/2 atau 7/1/1 → raw printer  → wajib encode ESC/P-R sendiri
     *   - Tidak ada class 7      → printer kemungkinan mode vendor-specific / belum siap
     */
    /** Hasil pemindaian satu kelompok interface. */
    private class IntfScan(
        val maps: List<Map<String, Any?>>,
        val ippUsb: Boolean,
        val rawPrinter: Boolean
    )

    /**
     * Pindai daftar UsbInterface, catat ke summary, dan tandai jalur yang ditemukan.
     */
    private fun scanInterfaces(
        list: List<UsbInterface>,
        sb: StringBuilder,
        indent: String
    ): IntfScan {
        var ippUsb = false
        var rawPrinter = false

        val maps = list.mapIndexed { i, intf ->
            val cls = intf.interfaceClass
            val sub = intf.interfaceSubclass
            val proto = intf.interfaceProtocol
            val isIppUsb = (cls == 7 && sub == 1 && proto == 4)
            val isRawPrinter = (cls == 7 && sub == 1 && (proto == 1 || proto == 2))

            if (isIppUsb) ippUsb = true
            if (isRawPrinter) rawPrinter = true

            val endpoints = (0 until intf.endpointCount).map { e ->
                val ep = intf.getEndpoint(e)
                val dir = if (ep.direction == UsbConstants.USB_DIR_IN) "IN" else "OUT"
                mapOf(
                    "address" to ep.address,
                    "number" to ep.endpointNumber,
                    "direction" to dir,
                    "type" to endpointTypeLabel(ep.type),
                    "maxPacketSize" to ep.maxPacketSize
                )
            }

            val epSummary = endpoints.joinToString(", ") {
                "${it["type"]}/${it["direction"]}#${it["number"]}"
            }
            sb.append("$indent if[$i] ${usbClassLabel(cls)} sub=$sub proto=$proto alt=${intf.alternateSetting}")
            if (cls == 7) sb.append(" → ${printerProtocolLabel(cls, sub, proto)}")
            sb.append("\n$indent    ep: ${if (epSummary.isEmpty()) "(none)" else epSummary}\n")

            mapOf(
                "index" to i,
                "id" to intf.id,
                "alternateSetting" to intf.alternateSetting,
                "interfaceClass" to cls,
                "interfaceSubclass" to sub,
                "interfaceProtocol" to proto,
                "classLabel" to usbClassLabel(cls),
                "protocolLabel" to printerProtocolLabel(cls, sub, proto),
                "isPrinterClass" to (cls == 7),
                "isIppUsb" to isIppUsb,
                "isRawPrinter" to isRawPrinter,
                "endpoints" to endpoints
            )
        }

        return IntfScan(maps, ippUsb, rawPrinter)
    }

    private fun probeUsbPrinterInterfaces(result: MethodChannel.Result) {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val allDevices = usbManager.deviceList.values.toList()

            var ippUsbFound = false
            var rawPrinterFound = false
            val summaryLines = StringBuilder()

            val deviceReports = allDevices.map { device ->
                val isEpson = device.vendorId == 0x04B8
                val vidPid = "%04X:%04X".format(device.vendorId, device.productId)

                summaryLines.append("● $vidPid  ${device.productName ?: "(no name)"}")
                if (isEpson) summaryLines.append("  [EPSON]")
                summaryLines.append("  cfg=${device.configurationCount}\n")

                // ── Konfigurasi aktif ──
                val activeScan = scanInterfaces(
                    (0 until device.interfaceCount).map { device.getInterface(it) },
                    summaryLines,
                    "   [active]"
                )
                if (isEpson) {
                    if (activeScan.ippUsb) ippUsbFound = true
                    if (activeScan.rawPrinter) rawPrinterFound = true
                }

                // ── SEMUA konfigurasi (IPP-USB kadang disembunyikan di config lain) ──
                val configReports = (0 until device.configurationCount).map { c ->
                    val cfg = device.getConfiguration(c)
                    summaryLines.append("   ┌ config[${cfg.id}] \"${cfg.name ?: ""}\" ${cfg.interfaceCount} intf\n")
                    val scan = scanInterfaces(
                        (0 until cfg.interfaceCount).map { cfg.getInterface(it) },
                        summaryLines,
                        "   │"
                    )
                    if (isEpson) {
                        if (scan.ippUsb) ippUsbFound = true
                        if (scan.rawPrinter) rawPrinterFound = true
                    }
                    mapOf(
                        "configIndex" to c,
                        "id" to cfg.id,
                        "name" to (cfg.name ?: ""),
                        "interfaceCount" to cfg.interfaceCount,
                        "hasIppUsb" to scan.ippUsb,
                        "interfaces" to scan.maps
                    )
                }

                mapOf(
                    "deviceName" to device.deviceName,
                    "productName" to (device.productName ?: ""),
                    "manufacturerName" to (device.manufacturerName ?: ""),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "vidPidHex" to vidPid,
                    "isEpson" to isEpson,
                    "hasPermission" to usbManager.hasPermission(device),
                    "deviceClass" to device.deviceClass,
                    "deviceClassLabel" to usbClassLabel(device.deviceClass),
                    "interfaceCount" to device.interfaceCount,
                    "configurationCount" to device.configurationCount,
                    "interfaces" to activeScan.maps,
                    "configurations" to configReports
                )
            }

            val epsonPresent = deviceReports.any { it["isEpson"] == true }

            val recommendedPath = when {
                ippUsbFound     -> "IPP_USB"
                rawPrinterFound -> "ESCPR_RAW"
                epsonPresent    -> "NO_PRINTER_INTERFACE"
                else            -> "NO_EPSON_DEVICE"
            }

            val verdict = when (recommendedPath) {
                "IPP_USB" -> "✅ IPP-over-USB TERSEDIA (7/1/4). Silent print langsung bisa " +
                             "diimplementasikan — kirim IPP Print-Job + PDF ke bulk endpoint, " +
                             "tanpa PrintManager & tanpa Accessibility Service."
                "ESCPR_RAW" -> "⚠️ Hanya interface printer raw (7/1/1 atau 7/1/2) di SEMUA konfigurasi " +
                               "USB. IPP-over-USB TIDAK ada. Silent print via USB wajib lewat encoder " +
                               "ESC/P-R. Alternatif jauh lebih ringan: IPP via Wi-Fi / Wi-Fi Direct."
                "NO_PRINTER_INTERFACE" -> "❌ Perangkat Epson terdeteksi tapi tidak expose interface " +
                               "class 7 (Printer). Cek: printer menyala penuh, kabel USB data (bukan " +
                               "charge-only), dan mode USB printer aktif di panel printer."
                else -> "❌ Tidak ada perangkat Epson (VID 0x04B8) di bus USB. Cek kabel OTG, hub, " +
                        "dan pastikan printer menyala."
            }

            Log.i(TAG, "🔍 USB PROBE — path=$recommendedPath\n$summaryLines")

            result.success(mapOf(
                "success" to true,
                "totalUsbDevices" to allDevices.size,
                "epsonPresent" to epsonPresent,
                "ippUsbSupported" to ippUsbFound,
                "rawPrinterSupported" to rawPrinterFound,
                "recommendedPath" to recommendedPath,
                "verdict" to verdict,
                "rawSummary" to summaryLines.toString().trimEnd(),
                "devices" to deviceReports
            ))
        } catch (e: Exception) {
            Log.e(TAG, "❌ probeUsbPrinterInterfaces error: ${e.message}")
            result.success(mapOf(
                "success" to false,
                "totalUsbDevices" to 0,
                "epsonPresent" to false,
                "ippUsbSupported" to false,
                "rawPrinterSupported" to false,
                "recommendedPath" to "ERROR",
                "verdict" to "❌ Gagal membaca USB descriptor: ${e.message}",
                "rawSummary" to "",
                "devices" to emptyList<Any>()
            ))
        }
    }

    /**
     * Konversi string quality dari Flutter ke PrintAttributes.Resolution (DPI).
     */
    private fun getResolutionObj(quality: String?): Resolution {
        return when (quality?.lowercase()) {
            "low" -> Resolution("low", "Low Quality (200 DPI)", 200, 200)
            "high" -> Resolution("high", "High Quality (600 DPI)", 600, 600)
            else -> Resolution("standard", "Standard Quality (300 DPI)", 300, 300)
        }
    }

    /**
     * Deteksi apakah ada USB printer (Epson L8050) terhubung via USB Host.
     * Hanya untuk informasi UI — data print tetap lewat PrintManager.
     */
    private fun detectUsbPrinter(result: MethodChannel.Result) {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val deviceList = usbManager.deviceList
            // Epson vendor ID: 0x04B8
            val epsonDevice = deviceList.values.firstOrNull { it.vendorId == 0x04B8 }
            if (epsonDevice != null) {
                result.success(mapOf(
                    "isDetected" to true,
                    "deviceName" to (epsonDevice.productName ?: "Epson Printer"),
                    "hasPermission" to usbManager.hasPermission(epsonDevice),
                    "status" to "connected"
                ))
            } else {
                result.success(mapOf(
                    "isDetected" to false,
                    "deviceName" to null,
                    "hasPermission" to false,
                    "status" to "disconnected"
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "detectUsbPrinter error: ${e.message}")
            result.success(mapOf(
                "isDetected" to false,
                "deviceName" to null,
                "hasPermission" to false,
                "status" to "error"
            ))
        }
    }

    /**
     * Cek apakah KioskAutoPrintService (Accessibility Service) sudah aktif.
     * Lebih akurat dari cek Epson Print Service — langsung cek service kita.
     */
    private fun isEpsonPrintServiceEnabled(): Boolean {
        return try {
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            val ourService = "$packageName/.KioskAutoPrintService"
            val isOurServiceEnabled = enabledServices.contains(ourService, ignoreCase = true)

            // Fallback: cek Epson Print Service juga
            val epsonEnabled = Settings.Secure.getString(
                contentResolver,
                "enabled_print_services"
            )?.contains("epson", ignoreCase = true) ?: false

            Log.i(TAG, "KioskAutoPrintService enabled: $isOurServiceEnabled, Epson Print Service: $epsonEnabled")
            isOurServiceEnabled || epsonEnabled
        } catch (e: Exception) {
            Log.e(TAG, "isEpsonPrintServiceEnabled error: ${e.message}")
            false
        }
    }

    /**
     * Status Kiosk Auto-Print Helper untuk panel settings.
     *
     * Penting ditampilkan ke operator: Accessibility Service bisa dimatikan
     * sistem setelah update/reboot, dan kalau itu terjadi jalur cetak USB
     * berhenti tanpa pesan apa pun.
     */
    private fun autoPrintHelperStatus(): Map<String, Any?> {
        val enabledInSettings = try {
            val enabled = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            enabled.contains("$packageName/.KioskAutoPrintService", ignoreCase = true) ||
                enabled.contains("$packageName/${KioskAutoPrintService::class.java.name}", ignoreCase = true)
        } catch (e: Exception) {
            false
        }

        return mapOf(
            "enabledInSettings" to enabledInSettings,
            "serviceRunning" to KioskAutoPrintService.isRunning(),
            "lastResult" to KioskAutoPrintService.lastResult,
            "lastSpoolerPackage" to KioskAutoPrintService.lastSpoolerPackage
        )
    }

    /**
     * Status printer ringkas untuk UI settings tab.
     */
    private fun getPrinterStatus(): Map<String, Any?> {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val deviceList = usbManager.deviceList
        val epsonDevice = deviceList.values.firstOrNull { it.vendorId == 0x04B8 }
        val epsonServiceEnabled = isEpsonPrintServiceEnabled()
        return mapOf(
            "usbConnected" to (epsonDevice != null),
            "usbDeviceName" to (epsonDevice?.productName ?: ""),
            "epsonServiceEnabled" to epsonServiceEnabled,
            "printManagerReady" to epsonServiceEnabled
        )
    }

    /**
     * Cetak foto langsung menggunakan Android PrintManager.
     * Akan menggunakan Epson Print Enabler yang sudah terpasang.
     * Ukuran kertas 4×6 inch, kualitas foto.
     */
    private fun printPhoto(
        imageBytes: ByteArray,
        jobName: String,
        borderless: Boolean,
        quality: String?,
        marginHoriz: Double,
        marginVert: Double,
        marginUnit: String,
        result: MethodChannel.Result
    ) {
        try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                result.error("DECODE_ERROR", "Gagal decode image bytes", null)
                return
            }

            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val resObj = getResolutionObj(quality)

            // Margin sesuai setting borderless
            val margins = if (borderless) Margins.NO_MARGINS
                          else Margins(500, 500, 500, 500) // 5mm border jika non-borderless

            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize.NA_INDEX_4X6)
                .setResolution(resObj)
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(margins)
                .build()

            Log.i(TAG, "🖨️ printPhoto — borderless=$borderless, quality=$quality, margins=$margins, marginHoriz=$marginHoriz $marginUnit, marginVert=$marginVert $marginUnit")

            // Buka jendela waktu agar KioskAutoPrintService menekan tombol Print
            // begitu dialog spooler muncul. Tanpa ini dialog akan menunggu operator.
            KioskAutoPrintService.arm()

            printManager.print(jobName, object : PrintDocumentAdapter() {
                override fun onLayout(
                    oldAttributes: PrintAttributes?,
                    newAttributes: PrintAttributes,
                    cancellationSignal: CancellationSignal?,
                    callback: LayoutResultCallback,
                    extras: Bundle?
                ) {
                    if (cancellationSignal?.isCanceled == true) {
                        callback.onLayoutCancelled()
                        return
                    }
                    val info = PrintDocumentInfo.Builder(jobName)
                        .setContentType(PrintDocumentInfo.CONTENT_TYPE_PHOTO)
                        .setPageCount(1)
                        .build()
                    callback.onLayoutFinished(info, true)
                }

                override fun onWrite(
                    pages: Array<out PageRange>?,
                    destination: ParcelFileDescriptor,
                    cancellationSignal: CancellationSignal?,
                    callback: WriteResultCallback
                ) {
                    try {
                        val printAttrs = PrintAttributes.Builder()
                            .setMediaSize(MediaSize.NA_INDEX_4X6)
                            .setResolution(resObj)
                            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                            .setMinMargins(margins)
                            .build()

                        val pdfDocument = PrintedPdfDocument(this@MainActivity, printAttrs)

                        // Canvas size dalam PDF points (1 point = 1/72 inch, 1 mm = 2.83465 pt)
                        val pageWidthPt  = (4.0 * 72).toInt()   // 288 pt
                        val pageHeightPt = (6.0 * 72).toInt()   // 432 pt

                        val pageInfo = PdfDocument.PageInfo.Builder(pageWidthPt, pageHeightPt, 0).create()
                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas

                        // Konversi margin kustom dari unit (mm/cm) ke PDF Points
                        val horizMm = if (marginUnit == "cm") marginHoriz * 10.0 else marginHoriz
                        val vertMm  = if (marginUnit == "cm") marginVert * 10.0 else marginVert
                        val marginHorizPt = (horizMm * 2.83465).toFloat()
                        val marginVertPt  = (vertMm * 2.83465).toFloat()

                        val targetWidthPt  = (canvas.width.toFloat()  - (2f * marginHorizPt)).coerceAtLeast(10f)
                        val targetHeightPt = (canvas.height.toFloat() - (2f * marginVertPt)).coerceAtLeast(10f)

                        val scaleX = targetWidthPt  / bitmap.width.toFloat()
                        val scaleY = targetHeightPt / bitmap.height.toFloat()
                        val scale  = maxOf(scaleX, scaleY)

                        val scaledWidth  = bitmap.width  * scale
                        val scaledHeight = bitmap.height * scale
                        val left = marginHorizPt + (targetWidthPt - scaledWidth)  / 2f
                        val top  = marginVertPt  + (targetHeightPt - scaledHeight) / 2f

                        canvas.save()
                        // Clip ke batas canvas agar tidak ada overflow
                        canvas.clipRect(0f, 0f, canvas.width.toFloat(), canvas.height.toFloat())
                        canvas.translate(left, top)
                        canvas.scale(scale, scale)
                        canvas.drawBitmap(bitmap, 0f, 0f, null)
                        canvas.restore()

                        pdfDocument.finishPage(page)
                        pdfDocument.writeTo(FileOutputStream(destination.fileDescriptor))
                        pdfDocument.close()

                        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                        Log.i(TAG, "✅ Print job written successfully (custom margin: H=$horizMm mm, V=$vertMm mm)")
                    } catch (e: IOException) {
                        callback.onWriteFailed(e.message)
                        Log.e(TAG, "❌ Write failed: ${e.message}")
                    }
                }

                override fun onFinish() {
                    super.onFinish()
                    bitmap.recycle()
                    // Spooler selesai memakai adapter — dialog sudah/segera tutup.
                    // Beri jeda pendek supaya transisi tidak berkedip.
                    coverHandler.postDelayed({ hidePrintCover() }, 600L)
                }
            }, attrs)

            Log.i(TAG, "🖨️ Print job submitted: $jobName")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Print error: ${e.message}")
            hidePrintCover()
            result.error("PRINT_ERROR", e.message, null)
        }
    }

    /**
     * Cetak PDF langsung menggunakan Android PrintManager.
     */
    private fun printPdf(
        pdfBytes: ByteArray,
        jobName: String,
        borderless: Boolean,
        quality: String?,
        marginHoriz: Double,
        marginVert: Double,
        marginUnit: String,
        result: MethodChannel.Result
    ) {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val resObj = getResolutionObj(quality)
            val margins = if (borderless) Margins.NO_MARGINS
                          else Margins(500, 500, 500, 500)

            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize.NA_INDEX_4X6)
                .setResolution(resObj)
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(margins)
                .build()

            Log.i(TAG, "🖨️ printPdf — borderless=$borderless, quality=$quality, margins=$margins")

            KioskAutoPrintService.arm()

            printManager.print(jobName, object : PrintDocumentAdapter() {
                override fun onLayout(
                    oldAttributes: PrintAttributes?,
                    newAttributes: PrintAttributes,
                    cancellationSignal: CancellationSignal?,
                    callback: LayoutResultCallback,
                    extras: Bundle?
                ) {
                    if (cancellationSignal?.isCanceled == true) {
                        callback.onLayoutCancelled()
                        return
                    }

                    // Jika borderless aktif, gunakan CONTENT_TYPE_PHOTO agar driver Epson mengaktifkan mode borderless
                    val contentType = if (borderless) PrintDocumentInfo.CONTENT_TYPE_PHOTO else PrintDocumentInfo.CONTENT_TYPE_DOCUMENT

                    val info = PrintDocumentInfo.Builder(jobName)
                        .setContentType(contentType)
                        .setPageCount(1)
                        .build()

                    callback.onLayoutFinished(info, true)
                }

                override fun onWrite(
                    pages: Array<out PageRange>?,
                    destination: ParcelFileDescriptor,
                    cancellationSignal: CancellationSignal?,
                    callback: WriteResultCallback
                ) {
                    try {
                        FileOutputStream(destination.fileDescriptor).use { out ->
                            out.write(pdfBytes)
                        }
                        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                        Log.i(TAG, "✅ PDF print job written successfully")
                    } catch (e: IOException) {
                        callback.onWriteFailed(e.message)
                        Log.e(TAG, "❌ PDF write failed: ${e.message}")
                    }
                }

                override fun onFinish() {
                    super.onFinish()
                    coverHandler.postDelayed({ hidePrintCover() }, 600L)
                }
            }, attrs)

            Log.i(TAG, "🖨️ PDF print job submitted: $jobName")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ PDF print error: ${e.message}")
            hidePrintCover()
            result.error("PRINT_ERROR", e.message, null)
        }
    }
}
