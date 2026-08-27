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

        // 1. Standar PTP OpenSession (SessionID=1, TransactionID=0 per PTP spec)
        Log.i(TAG, "PTP -> Mengirim OpenSession (0x1002, SessionID=1, TID=0)...")
        val respOpen = sendPtpCommand(PTP_OP_OPEN_SESSION, listOf(1), explicitTid = 0)
        if (respOpen.responseCode == PTP_RC_OK || respOpen.responseCode == PTP_RC_SESSION_ALREADY_OPEN) {
            Log.i(TAG, "✅ PTP OpenSession Berhasil! (Response=0x${respOpen.responseCode.toString(16)})")
            isSessionOpen = true
        } else {
            Log.w(TAG, "PTP OpenSession response: 0x${respOpen.responseCode.toString(16)}")
            // Tetap coba lanjutkan jika kamera sudah dalam state aktif
            isSessionOpen = true
        }

        Thread.sleep(50)

        // 2. Sony SDIO Handshake Phase 1 (0x9201, param1=1, param2=0) -> Membaca Data + Response
        try {
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 1)...")
            val res1 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(1, 0))
            Log.i(TAG, "   Phase 1 Response: 0x${res1.responseCode.toString(16)}, DataSize=${res1.data?.size ?: 0}")

            Thread.sleep(50)

            // Sony SDIO Handshake Phase 2 (0x9201, param1=2, param2=0)
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 2)...")
            val res2 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(2, 0))
            Log.i(TAG, "   Phase 2 Response: 0x${res2.responseCode.toString(16)}, DataSize=${res2.data?.size ?: 0}")

            Thread.sleep(50)

            // Sony SDIO Handshake Phase 3 (0x9201, param1=3, param2=0)
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 3)...")
            val res3 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(3, 0))
            Log.i(TAG, "   Phase 3 Response: 0x${res3.responseCode.toString(16)}")
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

            // Drain any pending data on endpoints first
            drainEndpoints()

            // 1. Shutter Press Phase 1: Half-Press (AF-Lock) -> SonyDoControl (0x9207, param1=0x0001, param2=0)
            Log.i(TAG, "⚡ S1: Shutter Half-Press (AF-Lock)...")
            val r1 = sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0001, 0))
            Log.i(TAG, "   S1 Response: 0x${r1.responseCode.toString(16)}")
            delay(150)

            // 2. Shutter Press Phase 2: Full-Press (Shutter Release Trigger!) -> (0x9207, param1=0x0002, param2=0)
            Log.i(TAG, "⚡ S2: Shutter Full-Release (Take Photo!)...")
            val r2 = sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0002, 0))
            Log.i(TAG, "   S2 Response: 0x${r2.responseCode.toString(16)}")
            delay(300)

            // 3. Shutter Release Off (Standby) -> (0x9207, param1=0x0000, param2=0)
            Log.i(TAG, "⚡ S0: Shutter Release Off...")
            sendPtpCommand(SONY_OP_DO_CONTROL, listOf(0x0000, 0))

            // Fallback juga kirim Standard InitiateCapture jika kamera di-set standard PTP
            try {
                sendPtpCommand(PTP_OP_INITIATE_CAPTURE, listOf(0, 0))
            } catch (_: Exception) {}

            // 4. Tunggu kamera simpan ke memory card (~1.5 detik)
            delay(1500)

            // 5. Download JPEG via PTP GetObjectHandles → GetObject
            val capturedFile = downloadLatestImageViaPtp()
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
                    "message" to "Shutter terpicu namun gagal download foto via PTP GetObject."
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

    private fun drainEndpoints() {
        try {
            val conn = usbConnection ?: return
            val epIn = endpointIn ?: return
            val epInt = endpointInt
            val buf = ByteArray(1024)
            // Drain bulk in
            while (conn.bulkTransfer(epIn, buf, buf.size, 50) > 0) {}
            // Drain interrupt in
            if (epInt != null) {
                while (conn.bulkTransfer(epInt, buf, epInt.maxPacketSize, 50) > 0) {}
            }
        } catch (_: Exception) {}
    }

    private fun clearEndpointHalt(endpoint: UsbEndpoint) {
        try {
            val conn = usbConnection ?: return
            // USB Standard Request: bmRequestType=0x02 (Host-to-Device, Standard, Endpoint recipient)
            // bRequest=0x01 (CLEAR_FEATURE), wValue=0x00 (ENDPOINT_HALT), wIndex=endpoint.address
            conn.controlTransfer(0x02, 0x01, 0x00, endpoint.address, null, 0, 1000)
            Log.i(TAG, "Un-stalled endpoint ${endpoint.address}")
        } catch (e: Exception) {
            Log.w(TAG, "clearEndpointHalt error: ${e.message}")
        }
    }

    /**
     * Membaca stream byte JPEG dari USB Bulk In Endpoint (0x81).
     * Format JPEG dimulai dengan magic bytes 0xFF, 0xD8 dan diakhiri dengan 0xFF, 0xD9.
     */
    /**
     * Download foto terbaru dari kamera Sony via PTP standard:
     * 1. GetObjectHandles (0x1007) — dapat list semua object di storage
     * 2. Ambil handle terakhir (foto paling baru)
     * 3. GetObject (0x1009) — download JPEG bytes
     *
     * Ini adalah cara yang benar untuk Sony ZV-E10 — kamera tidak push
     * raw JPEG ke bulk-in, melainkan menyimpan ke memory card dulu.
     */
    private fun downloadLatestImageViaPtp(): File? {
        val conn = usbConnection ?: return null

        // 1. GetObjectHandles: param1=0xFFFFFFFF (all storage),
        //    param2=0x00000000 (all formats), param3=0xFFFFFFFF (all objects)
        Log.i(TAG, "📂 PTP GetObjectHandles...")
        val handlesResp = sendPtpCommand(
            PTP_OP_GET_OBJECT_HANDLES,
            listOf(0xFFFFFFFF.toInt(), 0x00000000, 0xFFFFFFFF.toInt())
        )

        val handlesData = handlesResp.data
        if (handlesData == null || handlesData.size < 4) {
            Log.w(TAG, "GetObjectHandles: data kosong atau terlalu kecil (${handlesData?.size ?: 0} bytes)")
            return null
        }

        // Parse array of handles: [count(4)] [handle1(4)] [handle2(4)] ...
        val bb = ByteBuffer.wrap(handlesData).order(ByteOrder.LITTLE_ENDIAN)
        val count = bb.int
        Log.i(TAG, "GetObjectHandles: $count object ditemukan")

        if (count <= 0) {
            Log.w(TAG, "GetObjectHandles: tidak ada object di kamera")
            return null
        }

        // Ambil handle terakhir (foto paling baru)
        val handles = IntArray(count) { bb.int }
        val latestHandle = handles.last()
        Log.i(TAG, "📷 Mengambil object handle terbaru: 0x${latestHandle.toString(16)}")

        // 2. GetObject: download JPEG bytes untuk handle ini
        Log.i(TAG, "⬇️ PTP GetObject (0x${latestHandle.toString(16)})...")
        val objectResp = sendPtpCommand(PTP_OP_GET_OBJECT, listOf(latestHandle))

        val jpegBytes = objectResp.data
        if (jpegBytes == null || jpegBytes.size < 10000) {
            Log.w(TAG, "GetObject: data JPEG terlalu kecil atau kosong (${jpegBytes?.size ?: 0} bytes)")
            return null
        }

        // Verifikasi SOI marker JPEG (0xFF 0xD8)
        if ((jpegBytes[0].toInt() and 0xFF) != 0xFF || (jpegBytes[1].toInt() and 0xFF) != 0xD8) {
            Log.w(TAG, "GetObject: data tidak diawali JPEG SOI marker")
            return null
        }

        Log.i(TAG, "✅ JPEG valid: ${jpegBytes.size / 1024} KB")

        // Simpan ke file cache internal
        val photoDir = File(context.cacheDir, "sony_photos")
        if (!photoDir.exists()) photoDir.mkdirs()
        val photoFile = File(photoDir, "sony_capture_${System.currentTimeMillis()}.jpg")
        FileOutputStream(photoFile).use { it.write(jpegBytes) }

        Log.i(TAG, "💾 Foto disimpan: ${photoFile.absolutePath}")
        return photoFile
    }

    private fun readCapturedImageFromUsb(): File? {
        val conn = usbConnection ?: return null
        val epIn = endpointIn ?: return null

        val buffer = ByteArray(65536) // 64 KB chunk
        val outputStream = ByteArrayOutputStream()
        val startTime = System.currentTimeMillis()
        val timeoutMs = 8000 // Max 8 detik membaca full-res photo

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

    // ─── 6. Low-Level PTP Multi-Phase Packet Engine ─────────────────────────────

    private data class PtpResponse(val responseCode: Short, val data: ByteArray?)

    /**
     * Mengirim Command PTP dan membaca seluruh fasenya (Command -> Optional Data -> Response).
     * Menangani USB Pipe Stall dengan clearHalt otomatis.
     */
    private fun sendPtpCommand(opCode: Short, params: List<Int> = emptyList(), explicitTid: Int? = null): PtpResponse {
        val conn = usbConnection ?: return PtpResponse(0, null)
        val epOut = endpointOut ?: return PtpResponse(0, null)
        val epIn = endpointIn ?: return PtpResponse(0, null)

        val tid = explicitTid ?: transactionId++
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
        var outRes = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 1500)
        if (outRes < 0) {
            Log.w(TAG, "⚠️ Endpoint OUT stalled on 0x${opCode.toString(16)}, clearing halt...")
            try {
                clearEndpointHalt(epOut)
                outRes = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 1500)
            } catch (_: Exception) {}
            if (outRes < 0) {
                Log.e(TAG, "❌ Gagal mengirim PTP command 0x${opCode.toString(16)} setelah retry.")
                return PtpResponse(0, null)
            }
        }

        // Baca Response / Data Phases
        val inBuffer = ByteArray(65536)
        var responseCode: Short = 0
        val accumulatedData = ByteArrayOutputStream()

        var attempts = 0
        while (attempts < 5) {
            attempts++
            val inRes = conn.bulkTransfer(epIn, inBuffer, inBuffer.size, 1500)
            if (inRes < 12) {
                if (inRes < 0) {
                    try { clearEndpointHalt(epIn) } catch (_: Exception) {}
                }
                break
            }

            val rbb = ByteBuffer.wrap(inBuffer, 0, inRes).order(ByteOrder.LITTLE_ENDIAN)
            val containerLen = rbb.int
            val containerType = rbb.short
            val code = rbb.short
            val rTid = rbb.int

            if (containerType == PTP_CONTAINER_TYPE_DATA) {
                // Fasa DATA: Simpan payload
                val dataLen = inRes - 12
                if (dataLen > 0) {
                    accumulatedData.write(inBuffer, 12, dataLen)
                }
                // Jika data lebih besar dari 1 buffer chunk, baca sisanya
                var remaining = containerLen - inRes
                while (remaining > 0) {
                    val nextChunk = conn.bulkTransfer(epIn, inBuffer, minOf(inBuffer.size, remaining), 1500)
                    if (nextChunk > 0) {
                        accumulatedData.write(inBuffer, 0, nextChunk)
                        remaining -= nextChunk
                    } else {
                        break
                    }
                }
                // Lanjut loop untuk membaca Response Container berikutnya
            } else if (containerType == PTP_CONTAINER_TYPE_RESPONSE) {
                // Fasa RESPONSE
                responseCode = code
                break
            } else if (containerType == PTP_CONTAINER_TYPE_EVENT) {
                Log.d(TAG, "PTP Event received: 0x${code.toString(16)}")
            }
        }

        val finalData = if (accumulatedData.size() > 0) accumulatedData.toByteArray() else null
        return PtpResponse(responseCode, finalData)
    }
}
