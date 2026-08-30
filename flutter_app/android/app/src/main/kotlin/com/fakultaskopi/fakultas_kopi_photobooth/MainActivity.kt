package com.fakultaskopi.fakultas_kopi_photobooth

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
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
                    if (imageBytes != null) {
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
                    if (pdfBytes != null) {
                        printPdf(pdfBytes, jobName, borderless, quality, marginHoriz, marginVert, marginUnit, result)
                    } else {
                        result.error("INVALID_ARGS", "pdfBytes is null", null)
                    }
                }
                "detectUsbPrinter" -> detectUsbPrinter(result)
                "requestUsbPermission" -> result.success(false) // USB permission via dialog tidak diperlukan — PrintManager handle via Epson Print Service
                "isAutoPrintServiceEnabled" -> result.success(isEpsonPrintServiceEnabled())
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "getPrinterStatus" -> result.success(getPrinterStatus())
                else -> result.notImplemented()
            }
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
                }
            }, attrs)

            Log.i(TAG, "🖨️ Print job submitted: $jobName")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Print error: ${e.message}")
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
            }, attrs)

            Log.i(TAG, "🖨️ PDF print job submitted: $jobName")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ PDF print error: ${e.message}")
            result.error("PRINT_ERROR", e.message, null)
        }
    }
}
