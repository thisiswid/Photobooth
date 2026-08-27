package com.fakultaskopi.fakultas_kopi_photobooth

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * SonyPtpCameraManager
 *
 * Driver Native Kotlin untuk komunikasi langsung dengan kamera Sony ZV-E10 (dan seri Sony Alpha)
 * melalui Android USB Host API (android.hardware.usb.UsbManager) menggunakan protokol PTP
 * (Picture Transfer Protocol / ISO 15740) + Sony PTP Vendor Extension.
 *
 * Fitur:
 * - Deteksi otomatis Sony ZV-E10 (VID: 0x054C / 1356, PID: 0x0D97 / 3479)
 * - Request USB Permission & Claim Interface (Class 6, Subclass 1, Protocol 1)
 * - Handshake Sony PTP Session (OpenSession 0x1002 / SonySDIOConnect 0x9201)
 * - Trigger Remote Shutter Capture (SonyDoControl 0x9207 / InitiateCapture 0x100E)
 * - Direct Image Transfer via Bulk In Endpoint (0x81) dan simpan ke file JPEG
 */
class SonyPtpCameraManager(private val context: Context) {

    companion object {
        private const val TAG = "SonyPtpCamera"
        const val ACTION_USB_PERMISSION = "com.fakultaskopi.photobooth.USB_PERMISSION_SONY"

        const val SONY_VENDOR_ID = 0x054C    // 1356
        const val SONY_ZVE10_PID = 0x0D97    // 3479

        // PTP Container Types
        private const val PTP_CONTAINER_TYPE_COMMAND: Short = 1
        private const val PTP_CONTAINER_TYPE_DATA: Short = 2
        private const val PTP_CONTAINER_TYPE_RESPONSE: Short = 3
        private const val PTP_CONTAINER_TYPE_EVENT: Short = 4

        // Standard & Sony PTP OpCodes
        private const val PTP_OP_OPEN_SESSION: Short = 0x1002
        private const val PTP_OP_CLOSE_SESSION: Short = 0x1003
        private const val PTP_OP_GET_DEVICE_INFO: Short = 0x1001
        private const val PTP_OP_GET_OBJECT_HANDLES: Short = 0x1007
        private const val PTP_OP_GET_OBJECT: Short = 0x1009
        private const val PTP_OP_INITIATE_CAPTURE: Short = 0x100E

        // Sony Vendor OpCodes (0x92xx)
        private const val SONY_OP_SDIO_CONNECT: Short = 0x9201.toShort()
        private const val SONY_OP_GET_EXT_DEVICE_INFO: Short = 0x9202.toShort()
        private const val SONY_OP_GET_LIVEVIEW_IMAGE: Short = 0x9203.toShort()
        private const val SONY_OP_GET_PARTIAL_OBJECT: Short = 0x9205.toShort()
        private const val SONY_OP_DO_CONTROL: Short = 0x9207.toShort()

        // PTP Response Codes
        private const val PTP_RC_OK: Short = 0x2001
        private const val PTP_RC_SESSION_ALREADY_OPEN: Short = 0x201E
    }

    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var usbDevice: UsbDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpointIn: UsbEndpoint? = null
    private var endpointOut: UsbEndpoint? = null
    private var endpointInt: UsbEndpoint? = null

    private var transactionId = 1
    private var isSessionOpen = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ─── 1. Deteksi & Status Perangkat ──────────────────────────────────────────

    fun findSonyCamera(): UsbDevice? {
        val deviceList = usbManager.deviceList
        Log.i(TAG, "🔍 Memeriksa USB Host: ditemukan ${deviceList.size} perangkat:")
        for (device in deviceList.values) {
            Log.i(TAG, "   - ${device.deviceName}: ${device.productName ?: "Unknown"} (VID=${device.vendorId}, PID=${device.productId}, Interfaces=${device.interfaceCount})")
            
            // Match Sony VID (0x054C / 1356)
            if (device.vendorId == SONY_VENDOR_ID) {
                Log.i(TAG, "📸 Match Sony Vendor ID: ${device.productName ?: "ZV-E10"} (VID=${device.vendorId}, PID=${device.productId})")
                usbDevice = device
                return device
            }

            // Match PTP Class 6, Subclass 1, Protocol 1
            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                if (iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1) {
                    Log.i(TAG, "📸 Match PTP Interface: ${device.productName ?: "PTP Camera"} (VID=${device.vendorId}, PID=${device.productId})")
                    usbDevice = device
                    return device
                }
            }
        }
        usbDevice = null
        return null
    }

    fun getCameraStatus(): Map<String, Any?> {
        val dev = findSonyCamera()
        val hasPerm = dev != null && usbManager.hasPermission(dev)
        return mapOf(
            "isDetected" to (dev != null),
            "hasPermission" to hasPerm,
            "isConnected" to isSessionOpen,
            "productName" to (dev?.productName ?: if (dev != null) "Sony ZV-E10" else null),
            "vendorId" to dev?.vendorId,
            "productId" to dev?.productId,
            "devicePath" to dev?.deviceName,
            "serialNumber" to (if (hasPerm) dev?.serialNumber else null),
            "totalUsbDevices" to usbManager.deviceList.size
        )
    }

    // ─── 2. Request USB Permission ─────────────────────────────────────────────

    fun requestPermission(onResult: (Boolean) -> Unit) {
        val dev = findSonyCamera()
        if (dev == null) {
            Log.w(TAG, "Tidak ada kamera Sony terhubung untuk meminta izin.")
            onResult(false)
            return
        }

        if (usbManager.hasPermission(dev)) {
            Log.i(TAG, "USB Permission untuk Sony sudah tersedia.")
            onResult(true)
            return
        }

        val permissionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_USB_PERMISSION) {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    Log.i(TAG, "USB Permission result: granted=$granted")
                    try {
                        context?.unregisterReceiver(this)
                    } catch (_: Exception) {}
                    onResult(granted)
                }
            }
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(permissionReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(permissionReceiver, filter)
        }

        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
        usbManager.requestPermission(dev, pendingIntent)
        Log.i(TAG, "📢 usbManager.requestPermission dikirim untuk ${dev.deviceName}")
    }

    // ─── 3. Open Connection & Claim Interface ──────────────────────────────────

    @Synchronized
    fun openConnection(): Boolean {
        val dev = findSonyCamera() ?: return false
        if (!usbManager.hasPermission(dev)) {
            Log.e(TAG, "Belum ada USB permission untuk membuka koneksi.")
            return false
        }

        try {
            // Tutup koneksi lama jika ada
            closeConnection()

            val conn = usbManager.openDevice(dev) ?: run {
                Log.e(TAG, "Gagal openDevice (kemungkinan sedang digunakan proses lain).")
                return false
            }

            // Cari PTP Interface (Class 6, Subclass 1, Protocol 1)
            var targetIf: UsbInterface? = null
            for (i in 0 until dev.interfaceCount) {
                val iface = dev.getInterface(i)
                if (iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1) {
                    targetIf = iface
                    break
                }
            }

            // Fallback ke interface 0 jika class di-override
            val finalIf = targetIf ?: dev.getInterface(0)

            if (!conn.claimInterface(finalIf, true)) {
                Log.e(TAG, "Gagal claimInterface: ${finalIf.id}")
                conn.close()
                return false
            }

            // Temukan Endpoint IN (0x81), OUT (0x02), INT (0x83)
            var epIn: UsbEndpoint? = null
            var epOut: UsbEndpoint? = null
            var epInt: UsbEndpoint? = null

            for (i in 0 until finalIf.endpointCount) {
                val ep = finalIf.getEndpoint(i)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == UsbConstants.USB_DIR_IN) epIn = ep
                    else if (ep.direction == UsbConstants.USB_DIR_OUT) epOut = ep
                } else if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT) {
                    if (ep.direction == UsbConstants.USB_DIR_IN) epInt = ep
                }
            }

            if (epIn == null || epOut == null) {
                Log.e(TAG, "Endpoint IN/OUT tidak lengkap pada interface ${finalIf.id}")
                conn.releaseInterface(finalIf)
                conn.close()
                return false
            }

            usbConnection = conn
            usbInterface = finalIf
            endpointIn = epIn
            endpointOut = epOut
            endpointInt = epInt

            Log.i(TAG, "✅ USB Connection & Interface claimed successfully (IN=${epIn.address}, OUT=${epOut.address})")

            // Lakukan PTP Handshake (OpenSession)
            return initPtpSession()

        } catch (e: Exception) {
            Log.e(TAG, "Error saat openConnection: ${e.message}", e)
            closeConnection()
            return false
        }
    }

    @Synchronized
    fun closeConnection() {
        try {
            if (isSessionOpen) {
                sendPtpCommand(PTP_OP_CLOSE_SESSION, listOf(1))
                isSessionOpen = false
            }
            usbInterface?.let { usbConnection?.releaseInterface(it) }
            usbConnection?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error saat closeConnection: ${e.message}")
        } finally {
            usbConnection = null
            usbInterface = null
            endpointIn = null
            endpointOut = null
            endpointInt = null
            isSessionOpen = false
        }
    }

    // ─── 4. PTP Protocol & Handshake ───────────────────────────────────────────

    private fun initPtpSession(): Boolean {
        transactionId = 1

        // 1. Standar PTP OpenSession
        Log.i(TAG, "PTP -> Mengirim OpenSession (0x1002)...")
        val respOpen = sendPtpCommand(PTP_OP_OPEN_SESSION, listOf(1))
        if (respOpen.responseCode == PTP_RC_OK || respOpen.responseCode == PTP_RC_SESSION_ALREADY_OPEN) {
            Log.i(TAG, "✅ PTP OpenSession Berhasil!")
            isSessionOpen = true
        } else {
            Log.w(TAG, "PTP OpenSession response code: 0x${respOpen.responseCode.toString(16)}")
        }

        // 2. Sony SDIO Handshake Phase 1 & 2 (0x9201)
        try {
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 1)...")
            sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(1, 0))
            
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 2)...")
            sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(2, 0))

            Log.i(TAG, "Sony PTP -> Mengirim SonyGetExtDeviceInfo (0x9202)...")
            sendPtpCommand(SONY_OP_GET_EXT_DEVICE_INFO, listOf(0x012C, 0))
        } catch (e: Exception) {
            Log.w(TAG, "Sony extension handshake note: ${e.message}")
        }

        isSessionOpen = true
        return true
    }

    // ─── 5. Remote Capture & Image Transfer ───────────────────────────────────

    suspend fun capturePhoto(): Map<String, Any?> = withContext(Dispatchers.IO) {
        if (!isSessionOpen || usbConnection == null) {
            val opened = openConnection()
            if (!opened) {
                return@withContext mapOf(
                    "success" to false,
                    "message" to "Gagal menghubungkan kamera Sony via USB PTP."
                )
            }
        }

        try {
            Log.i(TAG, "📸 [Sony ZV-E10] Memulai Remote Shutter Capture via PTP...")

            // 1. Shutter Press Phase 1: Half-Press (AF-Lock)
            sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0001, 0))
            delay(150)

            // 2. Shutter Press Phase 2: Full-Press (Shutter Release Trigger!)
            sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0002, 0))
            Log.i(TAG, "⚡ Shutter Release signal sent!")
            delay(300)

            // 3. Shutter Release Off (Kembali ke standby)
            sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0000, 0))

            // Fallback juga kirim Standard InitiateCapture jika kamera di-set standard PTP
            try {
                sendPtpCommand(PTP_OP_INITIATE_CAPTURE, listOf(0, 0))
            } catch (_: Exception) {}

            // 4. Download JPEG image dari buffer USB kamera
            val capturedFile = readCapturedImageFromUsb()
            if (capturedFile != null && capturedFile.exists() && capturedFile.length() > 10000) {
                Log.i(TAG, "✅ [Sony ZV-E10] Foto berhasil diambil & ditransfer: ${capturedFile.absolutePath} (${capturedFile.length() / 1024} KB)")
                return@withContext mapOf(
                    "success" to true,
                    "filePath" to capturedFile.absolutePath,
                    "fileSizeBytes" to capturedFile.length(),
                    "message" to "Foto berhasil diambil dari Sony ZV-E10 (${capturedFile.length() / 1024} KB)"
                )
            } else {
                return@withContext mapOf(
                    "success" to false,
                    "message" to "Shutter terpicu namun data gambar tidak berhasil dibaca dari USB buffer."
                )
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error saat capturePhoto: ${e.message}", e)
            return@withContext mapOf(
                "success" to false,
                "message" to "Gagal capture: ${e.message}"
            )
        }
    }

    /**
     * Membaca stream byte JPEG dari USB Bulk In Endpoint (0x81).
     * Format JPEG dimulai dengan magic bytes 0xFF, 0xD8 dan diakhiri dengan 0xFF, 0xD9.
     */
    private fun readCapturedImageFromUsb(): File? {
        val conn = usbConnection ?: return null
        val epIn = endpointIn ?: return null

        val buffer = ByteArray(32768) // 32 KB chunk
        val outputStream = ByteArrayOutputStream()
        val startTime = System.currentTimeMillis()
        val timeoutMs = 7000 // Max 7 detik membaca full-res photo

        var foundJpegHeader = false
        var totalBytesRead = 0

        while (System.currentTimeMillis() - startTime < timeoutMs) {
            val bytesRead = conn.bulkTransfer(epIn, buffer, buffer.size, 1000)
            if (bytesRead > 0) {
                totalBytesRead += bytesRead

                if (!foundJpegHeader) {
                    // Cari SOI marker JPEG (0xFF, 0xD8)
                    for (i in 0 until bytesRead - 1) {
                        if ((buffer[i].toInt() and 0xFF) == 0xFF && (buffer[i + 1].toInt() and 0xFF) == 0xD8) {
                            foundJpegHeader = true
                            outputStream.write(buffer, i, bytesRead - i)
                            break
                        }
                    }
                } else {
                    outputStream.write(buffer, 0, bytesRead)

                    // Cek EOI marker JPEG (0xFF, 0xD9) di akhir chunk
                    if (bytesRead >= 2) {
                        val bLast2 = buffer[bytesRead - 2].toInt() and 0xFF
                        val bLast1 = buffer[bytesRead - 1].toInt() and 0xFF
                        if (bLast2 == 0xFF && bLast1 == 0xD9) {
                            Log.i(TAG, "🏁 JPEG End-of-Image (EOI 0xFFD9) ditemukan! Total: $totalBytesRead byte")
                            break
                        }
                    }
                }
            } else {
                if (foundJpegHeader && outputStream.size() > 50000) {
                    // Sudah tidak ada byte masuk dan ukuran file sudah > 50KB, selesai
                    break
                }
            }
        }

        val rawBytes = outputStream.toByteArray()
        if (rawBytes.isEmpty() || !foundJpegHeader) {
            Log.w(TAG, "Tidak menemukan valid JPEG header dari stream kamera.")
            return null
        }

        // Simpan ke file cache internal
        val photoDir = File(context.cacheDir, "sony_photos")
        if (!photoDir.exists()) photoDir.mkdirs()

        val photoFile = File(photoDir, "sony_capture_${System.currentTimeMillis()}.jpg")
        FileOutputStream(photoFile).use { fos ->
            fos.write(rawBytes)
        }

        return photoFile
    }

    // ─── 6. Low-Level PTP Packet Helper ────────────────────────────────────────

    private data class PtpResponse(val responseCode: Short, val data: ByteArray?)

    private fun sendPtpCommand(opCode: Short, params: List<Int> = emptyList()): PtpResponse {
        val conn = usbConnection ?: return PtpResponse(0, null)
        val epOut = endpointOut ?: return PtpResponse(0, null)
        val epIn = endpointIn ?: return PtpResponse(0, null)

        val tid = transactionId++
        val length = 12 + (params.size * 4)

        val bb = ByteBuffer.allocate(length).order(ByteOrder.LITTLE_ENDIAN)
        bb.putInt(length)                           // Container Length (4 bytes)
        bb.putShort(PTP_CONTAINER_TYPE_COMMAND)     // Container Type (2 bytes) = 1 (Command)
        bb.putShort(opCode)                         // Operation Code (2 bytes)
        bb.putInt(tid)                              // Transaction ID (4 bytes)
        for (param in params) {
            bb.putInt(param)                        // Parameter (4 bytes each)
        }

        val cmdBytes = bb.array()
        val outRes = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 1500)
        if (outRes < 0) {
            Log.w(TAG, "Gagal mengirim PTP command 0x${opCode.toString(16)}")
            return PtpResponse(0, null)
        }

        // Baca Response Container
        val respBuffer = ByteArray(512)
        val inRes = conn.bulkTransfer(epIn, respBuffer, respBuffer.size, 2000)
        if (inRes >= 12) {
            val rbb = ByteBuffer.wrap(respBuffer, 0, inRes).order(ByteOrder.LITTLE_ENDIAN)
            val rLen = rbb.int
            val rType = rbb.short
            val rCode = rbb.short
            return PtpResponse(rCode, respBuffer.copyOf(inRes))
        }

        return PtpResponse(0, null)
    }
}
