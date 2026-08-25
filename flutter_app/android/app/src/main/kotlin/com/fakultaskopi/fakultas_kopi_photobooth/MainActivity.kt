package com.fakultaskopi.fakultas_kopi_photobooth

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.usb.*
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.*
import android.print.PrintAttributes.*
import android.print.pdf.PrintedPdfDocument
import android.graphics.pdf.PdfDocument
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream
import java.io.IOException
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fakultaskopi.photobooth/printer"
    private val TAG = "PhotoboothPrinter"
    private val ACTION_USB_PERMISSION = "com.fakultaskopi.photobooth.USB_PERMISSION"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectUsbPrinter" -> detectUsbPrinter(result)
                "requestUsbPermission" -> requestUsbPermission(result)
                // ⚠️ Jalur "printUsbPhoto" (raw USB bulk transfer JPEG) DIHAPUS PERMANEN:
                // Epson L8050 membaca byte JPEG mentah sebagai perintah ESC/P →
                // hasil cetak berupa kode/angka acak. Semua printing sekarang lewat
                // Android PrintManager → Epson Print Service (raster resmi).
                // USB Host API hanya dipakai untuk deteksi/permission/status.
                "printPhoto" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val jobName = call.argument<String>("jobName") ?: "Photobooth_Print"
                    if (imageBytes != null) {
                        printPhoto(imageBytes, jobName, result)
                    } else {
                        result.error("INVALID_ARGS", "imageBytes is null", null)
                    }
                }
                "printPdf" -> {
                    val pdfBytes = call.argument<ByteArray>("pdfBytes")
                    val jobName = call.argument<String>("jobName") ?: "Photobooth_Print"
                    if (pdfBytes != null) {
                        printPdf(pdfBytes, jobName, result)
                    } else {
                        result.error("INVALID_ARGS", "pdfBytes is null", null)
                    }
                }
                // 🖨️ IPP Silent Print — kirim JPEG langsung ke printer via WiFi
                // tanpa Android PrintManager dialog / preview.
                "printPhotoIpp" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val jobName = call.argument<String>("jobName") ?: "Photobooth_Print"
                    val printerIp = call.argument<String>("printerIp") ?: "192.168.1.11"
                    if (imageBytes != null) {
                        printPhotoIpp(imageBytes, jobName, printerIp, result)
                    } else {
                        result.error("INVALID_ARGS", "imageBytes is null", null)
                    }
                }
                // 🖨️ AutoPrint Accessibility Service Helpers
                "isAutoPrintServiceEnabled" -> {
                    val enabled = isAccessibilityServiceEnabled(this, AutoPrintService::class.java)
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Find connected Epson USB printer (Vendor 0x04B8 or USB Class Printer 7) */
    private fun findEpsonUsbDevice(): UsbDevice? {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        for (device in usbManager.deviceList.values) {
            if (device.vendorId == 0x04B8 || device.deviceClass == UsbConstants.USB_CLASS_PRINTER) {
                return device
            }
            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                    return device
                }
            }
        }
        return null
    }

    private fun detectUsbPrinter(result: MethodChannel.Result) {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val device = findEpsonUsbDevice()
            if (device != null) {
                val hasPermission = usbManager.hasPermission(device)
                result.success(mapOf(
                    "isDetected" to true,
                    "deviceName" to (device.productName ?: "Epson L8050 USB"),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "hasPermission" to hasPermission,
                    "status" to if (hasPermission) "connected" else "permission_required"
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
            Log.e(TAG, "❌ Error detecting USB printer: ${e.message}")
            result.error("USB_DETECT_ERROR", e.message, null)
        }
    }

    private fun requestUsbPermission(result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val device = findEpsonUsbDevice()
        if (device == null) {
            result.success(false)
            return
        }
        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val permissionIntent = PendingIntent.getBroadcast(this, 0, Intent(ACTION_USB_PERMISSION), flags)

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        val usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (ACTION_USB_PERMISSION == intent.action) {
                    synchronized(this) {
                        unregisterReceiver(this)
                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        Log.i(TAG, "🔑 USB Permission granted: $granted")
                        result.success(granted)
                    }
                }
            }
        }
        registerReceiver(usbReceiver, filter)
        usbManager.requestPermission(device, permissionIntent)
    }

    /**
     * Cetak foto menggunakan Android PrintManager → Epson Print Service.
     * PrintActivity muncul dengan konfigurasi 4×6 sudah terisi — user hanya
     * perlu menekan tombol [Print] tanpa perlu masuk Settings atau memilih kertas.
     * Epson Print Service menangani rasterisasi ke ESC/P-R sehingga foto tercetak normal.
     */
    private fun printPhoto(imageBytes: ByteArray, jobName: String, result: MethodChannel.Result) {
        Thread {
            try {
                val bitmap = decodeForPrint(imageBytes)
                if (bitmap == null) {
                    runOnUiThread { result.error("DECODE_ERROR", "Gagal decode image bytes", null) }
                    return@Thread
                }
                runOnUiThread { submitPhotoPrint(bitmap, jobName, result) }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Photo print prepare error: ${e.message}")
                runOnUiThread { result.error("PRINT_ERROR", e.message, null) }
            }
        }.start()
    }

    /** Decode foto & downscale ke ukuran cetak (max 1800px sisi terpanjang ≈ 4x6 @ 300dpi). */
    private fun decodeForPrint(imageBytes: ByteArray): Bitmap? {
        val targetLong = 1800
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > targetLong * 2) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val src = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts) ?: return null

        val long = maxOf(src.width, src.height)
        if (long <= targetLong) return src
        val scale = targetLong.toFloat() / long
        val w = (src.width * scale).toInt().coerceAtLeast(1)
        val h = (src.height * scale).toInt().coerceAtLeast(1)
        val scaled = Bitmap.createScaledBitmap(src, w, h, true)
        if (scaled !== src) src.recycle()
        Log.i(TAG, "🖼️ Bitmap siap cetak: ${scaled.width}x${scaled.height}")
        return scaled
    }

    private fun submitPhotoPrint(bitmap: Bitmap, jobName: String, result: MethodChannel.Result) {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager

            // PrintAttributes 4×6 photo — pre-configured sehingga PrintActivity sudah siap
            // tanpa user perlu masuk Settings atau memilih kertas.
            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize.NA_INDEX_4X6)
                .setResolution(Resolution("high", "High Quality", 300, 300))
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(Margins.NO_MARGINS)
                .setDuplexMode(PrintAttributes.DUPLEX_MODE_NONE)  // sembunyikan opsi duplex
                .build()

            // Simpan attrs untuk perbandingan di onLayout agar hasLayoutChanged = false
            // ketika printer tidak mengubah atribut → dialog tidak reset printer selection.
            var lastAttrs: PrintAttributes? = null

            val printJob = printManager.print(jobName, object : PrintDocumentAdapter() {
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

                    // hasLayoutChanged = false jika atribut sama → PrintActivity tidak
                    // me-reset printer yang sudah terpilih ke default.
                    val changed = (lastAttrs == null || lastAttrs != newAttributes)
                    lastAttrs = newAttributes
                    Log.d(TAG, "📐 onLayout hasChanged=$changed mediaSize=${newAttributes.mediaSize}")
                    callback.onLayoutFinished(info, changed)
                }

                override fun onWrite(
                    pages: Array<out PageRange>?,
                    destination: ParcelFileDescriptor,
                    cancellationSignal: CancellationSignal?,
                    callback: WriteResultCallback
                ) {
                    try {
                        // Buat PDF document dengan ukuran 4x6 inch @ 72 dpi (PDF points)
                        val printAttrs = PrintAttributes.Builder()
                            .setMediaSize(MediaSize.NA_INDEX_4X6)
                            .setResolution(Resolution("photo", "Photo", 300, 300))
                            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                            .setMinMargins(Margins.NO_MARGINS)
                            .build()

                        val pdfDocument = PrintedPdfDocument(this@MainActivity, printAttrs)

                        val pageInfo = PdfDocument.PageInfo.Builder(
                            (4.0 * 72).toInt(),  // 288 PDF points = 4 inch
                            (6.0 * 72).toInt(),  // 432 PDF points = 6 inch
                            0
                        ).create()

                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas

                        // Gambar foto ke canvas — fit cover agar foto mengisi penuh 4×6
                        val scaleX = canvas.width.toFloat() / bitmap.width.toFloat()
                        val scaleY = canvas.height.toFloat() / bitmap.height.toFloat()
                        val scale = maxOf(scaleX, scaleY)

                        val scaledWidth = bitmap.width * scale
                        val scaledHeight = bitmap.height * scale
                        val left = (canvas.width - scaledWidth) / 2f
                        val top = (canvas.height - scaledHeight) / 2f

                        canvas.save()
                        canvas.translate(left, top)
                        canvas.scale(scale, scale)
                        canvas.drawBitmap(bitmap, 0f, 0f, null)
                        canvas.restore()

                        pdfDocument.finishPage(page)

                        pdfDocument.writeTo(FileOutputStream(destination.fileDescriptor))
                        pdfDocument.close()

                        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                        Log.i(TAG, "✅ PRINT_JOB_WRITTEN: $jobName")
                    } catch (e: IOException) {
                        callback.onWriteFailed(e.message)
                        Log.e(TAG, "❌ PRINT_WRITE_FAILED: ${e.message}")
                    }
                }

                override fun onFinish() {
                    super.onFinish()
                    bitmap.recycle()
                    Log.d(TAG, "🏁 PRINT_JOB_FINISHED: bitmap recycled")
                }
            }, attrs)

            Log.i(TAG, "🖨️ PRINT_JOB_CREATED: $jobName — PrintActivity akan terbuka dengan 4×6 pre-configured")
            watchPrintJob(printJob, result)
        } catch (e: Exception) {
            Log.e(TAG, "❌ PRINT_ERROR: ${e.message}")
            result.error("PRINT_ERROR", e.message, null)
        }
    }

    private fun watchPrintJob(printJob: PrintJob, result: MethodChannel.Result) {
        // Segera kembalikan sukses setelah PrintJob dibuat (state CREATED).
        // PrintActivity sudah terbuka dan menunggu user menekan [Print].
        // Kita tidak perlu menunggu user — cukup konfirmasi job berhasil dibuat.
        // Epson Print Service akan menangani rasterisasi dan pengiriman ke printer.
        val state = printJob.info.state
        Log.i(TAG, "🖨️ PRINT_JOB_READY: state=$state — job dikirim ke print spooler")
        result.success(true)
    }

    private fun printPdf(pdfBytes: ByteArray, jobName: String, result: MethodChannel.Result) {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager

            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize.NA_INDEX_4X6)
                .setResolution(Resolution("high", "High Quality", 300, 300))
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(Margins.NO_MARGINS)
                .build()

            val printJob = printManager.print(jobName, object : PrintDocumentAdapter() {
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
                        .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
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
            watchPrintJob(printJob, result)
        } catch (e: Exception) {
            Log.e(TAG, "❌ PDF print error: ${e.message}")
            result.error("PRINT_ERROR", e.message, null)
        }
    }

    /**
     * 🖨️ IPP Silent Print — kirim JPEG langsung ke Epson L8050 via WiFi.
     * Tidak menggunakan Android PrintManager → TIDAK ADA dialog / preview.
     *
     * Implementasi IPP (Internet Printing Protocol) manual via HTTP POST.
     * IPP = HTTP POST ke port 631 dengan binary-encoded payload.
     * Tidak butuh library external — hanya java.net.HttpURLConnection.
     *
     * Cocok untuk kiosk mode di mana printing harus fully automatic.
     */
    private fun printPhotoIpp(imageBytes: ByteArray, jobName: String, printerIp: String, result: MethodChannel.Result) {
        Thread {
            try {
                // 1. Pastikan data adalah JPEG murni (jika dari backend berupa PNG/WebP, konversi ke JPEG)
                val finalJpegBytes: ByteArray
                val bitmap = decodeForPrint(imageBytes)
                if (bitmap != null) {
                    val baos = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, baos)
                    finalJpegBytes = baos.toByteArray()
                    bitmap.recycle()
                    Log.i(TAG, "🖼️ Foto dikonversi ke JPEG (${finalJpegBytes.size} bytes)")
                } else {
                    finalJpegBytes = imageBytes
                }

                // Daftar kandidat endpoint IPP Epson (port 631 standar, port 80 alternatif)
                val candidateUrls = listOf(
                    "http://$printerIp:631/ipp/print",
                    "http://$printerIp:631/ipp/printer",
                    "http://$printerIp:80/ipp/print",
                    "http://$printerIp:80/ipp/printer"
                )

                var isPrinted = false
                var lastErrorMessage = ""

                for (targetUrl in candidateUrls) {
                    try {
                        val uriScheme = targetUrl.replace("http://", "ipp://")
                        Log.i(TAG, "🖨️ Mencoba IPP Silent Print ke: $targetUrl")

                        val ippPayload = buildIppPrintJobRequest(uriScheme, jobName, "image/jpeg")

                        val url = URL(targetUrl)
                        val connection = url.openConnection() as HttpURLConnection
                        connection.requestMethod = "POST"
                        connection.doOutput = true
                        connection.setRequestProperty("Content-Type", "application/ipp")
                        connection.setRequestProperty("Accept", "application/ipp")
                        connection.connectTimeout = 3000  // 3 detik timeout koneksi per endpoint
                        connection.readTimeout = 30000

                        val outputStream = connection.outputStream
                        outputStream.write(ippPayload)
                        outputStream.write(finalJpegBytes)
                        outputStream.flush()
                        outputStream.close()

                        val responseCode = connection.responseCode
                        Log.d(TAG, "📡 Response dari $targetUrl: $responseCode")

                        if (responseCode == 200) {
                            val responseStream = connection.inputStream
                            val responseBytes = responseStream.readBytes()
                            responseStream.close()

                            if (responseBytes.size >= 4) {
                                val statusHigh = responseBytes[2].toInt() and 0xFF
                                val statusLow = responseBytes[3].toInt() and 0xFF
                                val statusCode = (statusHigh shl 8) or statusLow

                                Log.i(TAG, "📋 IPP Status Code: 0x${String.format("%04X", statusCode)}")

                                if (statusCode <= 0x00FF) {
                                    Log.i(TAG, "✅ IPP Print Job berhasil dikirim via $targetUrl! (silent, tanpa dialog)")
                                    isPrinted = true
                                    connection.disconnect()
                                    break
                                } else {
                                    lastErrorMessage = "IPP error status: 0x${String.format("%04X", statusCode)}"
                                }
                            } else {
                                Log.w(TAG, "⚠️ Response pendek tapi HTTP 200 — dianggap berhasil")
                                isPrinted = true
                                connection.disconnect()
                                break
                            }
                        } else {
                            lastErrorMessage = "HTTP error $responseCode"
                        }
                        connection.disconnect()
                    } catch (endpointEx: Exception) {
                        Log.w(TAG, "⚠️ Gagal di endpoint $targetUrl: ${endpointEx.message}")
                        lastErrorMessage = endpointEx.message ?: "Endpoint failed"
                    }
                }

                if (isPrinted) {
                    runOnUiThread { result.success(true) }
                } else {
                    Log.e(TAG, "❌ Semua kandidat IPP gagal. Pesan terakhir: $lastErrorMessage")
                    runOnUiThread { result.error("IPP_ERROR", lastErrorMessage, null) }
                }

            } catch (e: Exception) {
                Log.e(TAG, "❌ IPP Print fatal error: ${e.message}", e)
                runOnUiThread { result.error("IPP_ERROR", e.message ?: "IPP print failed", null) }
            }
        }.start()
    }

    /**
     * Build binary IPP Print-Job request sesuai RFC 8010.
     * Format: version(2) + operation(2) + request-id(4) + attributes + end-tag(1)
     */
    private fun buildIppPrintJobRequest(printerUri: String, jobName: String, documentFormat: String): ByteArray {
        val baos = ByteArrayOutputStream()
        val dos = DataOutputStream(baos)

        // IPP Version 1.1
        dos.writeByte(0x01) // major
        dos.writeByte(0x01) // minor

        // Operation: Print-Job (0x0002)
        dos.writeShort(0x0002)

        // Request ID
        dos.writeInt(1)

        // === Operation Attributes Group (tag 0x01) ===
        dos.writeByte(0x01)

        // attributes-charset = utf-8
        writeIppAttribute(dos, 0x47, "attributes-charset", "utf-8")
        // attributes-natural-language = en
        writeIppAttribute(dos, 0x48, "attributes-natural-language", "en")
        // printer-uri
        writeIppAttribute(dos, 0x45, "printer-uri", printerUri)
        // document-format = image/jpeg
        writeIppAttribute(dos, 0x49, "document-format", documentFormat)

        // === Job Attributes Group (tag 0x02) ===
        dos.writeByte(0x02)

        // job-name
        writeIppAttribute(dos, 0x42, "job-name", jobName)

        // === End of Attributes (tag 0x03) ===
        dos.writeByte(0x03)

        dos.flush()
        return baos.toByteArray()
    }

    /** Write a single IPP text/uri/keyword attribute: tag(1) + name-length(2) + name + value-length(2) + value */
    private fun writeIppAttribute(dos: DataOutputStream, valueTag: Int, name: String, value: String) {
        dos.writeByte(valueTag)
        dos.writeShort(name.length)
        dos.writeBytes(name)
        dos.writeShort(value.toByteArray(Charsets.UTF_8).size)
        dos.write(value.toByteArray(Charsets.UTF_8))
    }

    /** Cek apakah AutoPrintService aktif di Accessibility Settings Android */
    private fun isAccessibilityServiceEnabled(context: Context, service: Class<out android.accessibilityservice.AccessibilityService>): Boolean {
        val expectedComponentName = "${context.packageName}/${service.name}"
        val enabledServices = android.provider.Settings.Secure.getString(
            context.contentResolver,
            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}

