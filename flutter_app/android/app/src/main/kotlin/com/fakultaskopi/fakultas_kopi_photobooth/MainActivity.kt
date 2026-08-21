package com.fakultaskopi.fakultas_kopi_photobooth

import android.content.Context
import android.graphics.BitmapFactory
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
                else -> result.notImplemented()
            }
        }
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

            // Set atribut print: 4x6 inch, foto, warna
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
                        // Buat PDF document dengan ukuran 4x6 inch
                        val printAttrs = PrintAttributes.Builder()
                            .setMediaSize(MediaSize("4x6", "4x6 Photo", 4000, 6000))
                            .setResolution(Resolution("photo", "Photo", 300, 300))
                            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                            .setMinMargins(Margins.NO_MARGINS)
                            .build()

                        val pdfDocument = PrintedPdfDocument(this@MainActivity, printAttrs)

                        val pageInfo = PdfDocument.PageInfo.Builder(
                            (4.0 * 72).toInt(),  // 4 inch @ 72 DPI (PDF points)
                            (6.0 * 72).toInt(),  // 6 inch @ 72 DPI (PDF points)
                            0
                        ).create()

                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas

                        // Gambar foto ke canvas, fit cover
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

                        // Tulis ke output
                        pdfDocument.writeTo(FileOutputStream(destination.fileDescriptor))
                        pdfDocument.close()

                        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                        Log.i(TAG, "✅ Print job written successfully")
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
