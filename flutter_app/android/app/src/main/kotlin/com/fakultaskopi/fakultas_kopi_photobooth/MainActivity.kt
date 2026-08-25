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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fakultaskopi.photobooth/printer"
    private val TAG = "PhotoboothPrinter"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
    private fun printPhoto(imageBytes: ByteArray, jobName: String, result: MethodChannel.Result) {
        try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                result.error("DECODE_ERROR", "Gagal decode image bytes", null)
                return
            }

            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager

            // Set atribut print: 4x6 inch, foto, warna, NO MARGINS (full bleed)
            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize("4x6", "4x6 Photo", 4000, 6000))
                .setResolution(Resolution("high", "High Quality", 600, 600))
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(Margins.NO_MARGINS)
                .build()

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
                            .setMediaSize(MediaSize("4x6", "4x6 Photo", 4000, 6000))
                            .setResolution(Resolution("photo", "Photo", 600, 600))
                            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                            .setMinMargins(Margins.NO_MARGINS)
                            .build()

                        val pdfDocument = PrintedPdfDocument(this@MainActivity, printAttrs)

                        // Canvas size dalam PDF points (1 point = 1/72 inch)
                        val pageWidthPt  = (4.0 * 72).toInt()   // 288 pt
                        val pageHeightPt = (6.0 * 72).toInt()   // 432 pt

                        val pageInfo = PdfDocument.PageInfo.Builder(pageWidthPt, pageHeightPt, 0).create()
                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas

                        // Full bleed cover: isi seluruh canvas tanpa sisa putih
                        val scaleX = canvas.width.toFloat()  / bitmap.width.toFloat()
                        val scaleY = canvas.height.toFloat() / bitmap.height.toFloat()
                        val scale  = maxOf(scaleX, scaleY)  // cover (bukan fit)

                        val scaledWidth  = bitmap.width  * scale
                        val scaledHeight = bitmap.height * scale
                        val left = (canvas.width  - scaledWidth)  / 2f
                        val top  = (canvas.height - scaledHeight) / 2f

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
                        Log.i(TAG, "✅ Print job written successfully (full bleed)")
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
    private fun printPdf(pdfBytes: ByteArray, jobName: String, result: MethodChannel.Result) {
        try {
            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager

            val attrs = PrintAttributes.Builder()
                .setMediaSize(MediaSize("4x6", "4x6 Photo", 4000, 6000))
                .setResolution(Resolution("high", "High Quality", 300, 300))
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setMinMargins(Margins.NO_MARGINS)
                .build()

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
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ PDF print error: ${e.message}")
            result.error("PRINT_ERROR", e.message, null)
        }
    }
}
