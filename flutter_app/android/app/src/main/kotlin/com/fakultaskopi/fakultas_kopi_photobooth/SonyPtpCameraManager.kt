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

        const val CAPTURE_CARD_MACROSILICON_VID = 0x534D // 21325 (MacroSilicon)
        const val CAPTURE_CARD_MS2109_PID = 0x2109      // 8457 (MS2109 / USB Video HDMI)

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
        // GetAllExtDevicePropInfo — WAJIB dipanggil setelah handshake sebelum
        // perintah kontrol (0x9207) diterima kamera.
        private const val SONY_OP_GET_ALL_EXT_DEVICE_PROP_INFO: Short = 0x9209.toShort()
        private const val SONY_OP_GET_LIVEVIEW_IMAGE: Short = 0x9203.toShort()
        private const val SONY_OP_GET_PARTIAL_OBJECT: Short = 0x9205.toShort()
        private const val SONY_OP_DO_CONTROL: Short = 0x9207.toShort()

        // PTP Response Codes
        private const val PTP_RC_OK: Short = 0x2001
        private const val PTP_RC_SESSION_ALREADY_OPEN: Short = 0x201E
        private const val PTP_RC_ACCESS_DENIED: Short = 0x2005

        // PTP Event Codes
        private const val PTP_EC_OBJECT_ADDED: Short = 0x4002

        // Sony Shutter Property Values (per libgphoto2 / Sony Remote SDK)
        private const val SONY_SHUTTER_PRESS: Byte = 0x02   // press (half or full)
        private const val SONY_SHUTTER_RELEASE: Byte = 0x01 // release button
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

    /**
     * True hanya bila handshake Sony SDIO benar-benar diterima kamera
     * (Phase 1 mengembalikan 0x2001). USB ter-claim saja TIDAK cukup: kalau
     * kamera masih di mode MTP / Mass Storage, semua perintah shutter akan
     * ditolak dengan 0xA101. Dipakai agar aplikasi langsung memakai jalur
     * HDMI daripada membuang waktu di setiap jepretan.
     */
    private var isRemoteReady = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ─── 1. Deteksi & Status Perangkat ──────────────────────────────────────────

    fun isUvcDevice(device: UsbDevice?): Boolean {
        if (device == null) return false
        if (device.vendorId == CAPTURE_CARD_MACROSILICON_VID) return true
        val pName = (device.productName ?: "").lowercase()
        if (pName.contains("usb video") || pName.contains("capture") || pName.contains("cam link")) return true
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == 14) return true // USB Video Class (UVC)
        }
        return false
    }

    /** Perangkat yang dipakai untuk PTP (kamera Sony asli), bukan capture card. */
    private var ptpDevice: UsbDevice? = null

    /** True bila device adalah kamera PTP/MTP (Class 6, Sub 1, Proto 1). */
    fun isPtpDevice(device: UsbDevice?): Boolean {
        if (device == null) return false
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == 6 && iface.interfaceSubclass == 1) return true
        }
        return device.vendorId == SONY_VENDOR_ID
    }

    /** Cari HDMI capture card (jalur LIVE PREVIEW). */
    fun findUvcDevice(): UsbDevice? {
        for (device in usbManager.deviceList.values) {
            if (device.vendorId == CAPTURE_CARD_MACROSILICON_VID && device.productId == CAPTURE_CARD_MS2109_PID) {
                return device
            }
        }
        for (device in usbManager.deviceList.values) {
            if (isUvcDevice(device)) return device
        }
        return null
    }

    /**
     * Cari kamera Sony untuk jalur PTP (jalur SHUTTER).
     * PENTING: capture card di-EXCLUDE di sini. Sebelumnya findSonyCamera()
     * selalu mengembalikan capture card lebih dulu, sehingga jalur PTP
     * (kabel C-to-C) tidak pernah bisa dipakai saat HDMI juga tertancap.
     */
    fun findPtpCamera(): UsbDevice? {
        val devices = usbManager.deviceList.values
        // 1. Sony Vendor ID + PTP interface
        for (device in devices) {
            if (device.vendorId == SONY_VENDOR_ID && isPtpDevice(device)) {
                ptpDevice = device
                return device
            }
        }
        // 2. Sony Vendor ID apa pun (mode MTP / Mass Storage)
        for (device in devices) {
            if (device.vendorId == SONY_VENDOR_ID) {
                ptpDevice = device
                return device
            }
        }
        // 3. Kamera PTP merek lain — tapi jangan ambil capture card
        for (device in devices) {
            if (isUvcDevice(device)) continue
            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                if (iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1) {
                    ptpDevice = device
                    return device
                }
            }
        }
        ptpDevice = null
        return null
    }

    /**
     * Kompatibilitas lama: mengembalikan device "utama".
     * Prioritas capture card dipertahankan HANYA untuk pelaporan status.
     */
    fun findSonyCamera(): UsbDevice? {
        val deviceList = usbManager.deviceList
        Log.i(TAG, "🔍 Memeriksa USB Host: ditemukan ${deviceList.size} perangkat:")
        for (device in deviceList.values) {
            Log.i(TAG, "   - ${device.deviceName}: ${device.productName ?: "Unknown"} (VID=0x${device.vendorId.toString(16)}, PID=0x${device.productId.toString(16)}, Interfaces=${device.interfaceCount})")
        }
        val uvc = findUvcDevice()
        val ptp = findPtpCamera()
        Log.i(TAG, "📹 UVC/HDMI capture: ${uvc?.productName ?: "(tidak ada)"}  |  📸 PTP camera: ${ptp?.productName ?: "(tidak ada)"}")
        usbDevice = uvc ?: ptp
        return usbDevice
    }

    /** True bila kamera Sony benar-benar menerima perintah PC Remote. */
    fun isRemoteControlReady(): Boolean = isSessionOpen && isRemoteReady

    fun getCameraStatus(): Map<String, Any?> {
        findSonyCamera() // refresh uvcDevice + ptpDevice
        val uvc = findUvcDevice()
        val ptp = findPtpCamera()
        val dev = uvc ?: ptp

        val uvcHasPerm = uvc != null && usbManager.hasPermission(uvc)
        val ptpHasPerm = ptp != null && usbManager.hasPermission(ptp)

        val isUvc = uvc != null
        val productName = when {
            dev == null -> null
            isUvc -> uvc?.productName ?: "USB Video (HDMI Capture Card)"
            ptp?.vendorId == SONY_VENDOR_ID -> ptp.productName ?: "Sony ZV-E10"
            else -> dev.productName ?: "Camera Device"
        }

        return mapOf(
            // ── legacy keys (dipakai UI lama) ─────────────────────────────────
            "isDetected" to (dev != null),
            // JUJUR: tidak lagi selalu true untuk UVC. Preview UVC butuh
            // izin USB device yang di-handle oleh library AUSBC.
            "hasPermission" to (if (isUvc) uvcHasPerm else ptpHasPerm),
            "isConnected" to (if (isUvc) true else isSessionOpen),
            "isUvc" to isUvc,
            "productName" to productName,
            "vendorId" to dev?.vendorId,
            "productId" to dev?.productId,
            "devicePath" to dev?.deviceName,
            "serialNumber" to (if (ptpHasPerm) ptp?.serialNumber else null),
            "totalUsbDevices" to usbManager.deviceList.size,

            // ── HYBRID keys (baru) ────────────────────────────────────────────
            "uvcDetected" to (uvc != null),
            "uvcHasPermission" to uvcHasPerm,
            "uvcProductName" to uvc?.productName,
            "uvcDevicePath" to uvc?.deviceName,
            "ptpDetected" to (ptp != null),
            "ptpHasPermission" to ptpHasPerm,
            "ptpProductName" to ptp?.productName,
            "ptpDevicePath" to ptp?.deviceName,
            "ptpSessionOpen" to isSessionOpen,
            "ptpRemoteReady" to isRemoteReady,
            "isSony" to (ptp?.vendorId == SONY_VENDOR_ID),
            "androidSdkInt" to Build.VERSION.SDK_INT
        )
    }

    // ─── 2. Request USB Permission ─────────────────────────────────────────────

    /** Minta izin USB untuk kamera PTP (kabel C-to-C). */
    fun requestPermission(onResult: (Boolean) -> Unit) =
        requestUsbPermissionFor(findPtpCamera(), "PTP/Sony", onResult)

    /** Minta izin USB untuk HDMI capture card (jalur preview UVC). */
    fun requestUvcPermission(onResult: (Boolean) -> Unit) =
        requestUsbPermissionFor(findUvcDevice(), "UVC/HDMI", onResult)

    private fun requestUsbPermissionFor(dev: UsbDevice?, label: String, onResult: (Boolean) -> Unit) {
        if (dev == null) {
            Log.w(TAG, "Tidak ada perangkat $label terhubung untuk meminta izin.")
            onResult(false)
            return
        }

        if (usbManager.hasPermission(dev)) {
            Log.i(TAG, "USB Permission untuk $label sudah tersedia.")
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
        // PENTING: pakai findPtpCamera(), BUKAN findSonyCamera().
        // findSonyCamera() memprioritaskan HDMI capture card sehingga jalur PTP
        // tidak pernah terbuka saat kedua kabel tertancap (mode hybrid).
        val dev = findPtpCamera()
        if (dev == null) {
            Log.e(TAG, "Kamera PTP tidak ditemukan. Pastikan kabel USB C-to-C tersambung " +
                "dan kamera di mode: MENU -> Setup -> USB -> USB Connection = PC Remote.")
            isRemoteReady = false
            return false
        }
        if (!usbManager.hasPermission(dev)) {
            Log.e(TAG, "Belum ada USB permission untuk membuka koneksi PTP.")
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
                Log.i(TAG, "   Interface[$i]: class=${iface.interfaceClass}, subclass=${iface.interfaceSubclass}, protocol=${iface.interfaceProtocol}")
                if (iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1) {
                    targetIf = iface
                    break
                }
            }

            // Fallback ke interface 0 jika class di-override
            val finalIf = targetIf ?: dev.getInterface(0)

            // Peringatan jika bukan PTP class — kamera mungkin di mode MTP
            if (targetIf == null) {
                Log.w(TAG, "⚠️ Tidak ditemukan PTP interface (class=6,subclass=1,protocol=1). " +
                    "Kamera kemungkinan dalam mode MTP/Mass Storage, bukan PC Remote. " +
                    "Di kamera: MENU → Network → PC Remote Function → PC Remote = ON, " +
                    "USB Connection = PC Remote.")
            }

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

            // ─── STRATEGI DUA TAHAP ───
            //
            // Dulu di sini SELALU dikirim PTP Device Reset (0x66) + CloseSession
            // sebelum OpenSession. Urutan itu terlalu agresif untuk Sony:
            // Device Reset dapat menjatuhkan kamera dari state PC Remote, dan
            // CloseSession pada koneksi yang baru dibuka (belum ada sesi) bisa
            // membuat kamera berhenti menjawab sama sekali — persis gejala
            // "OpenSession 0x0000" yang kita kejar.
            //
            // libgphoto2 tidak melakukan keduanya: cukup claim interface lalu
            // OpenSession. Jadi jalur bersih dicoba LEBIH DULU, dan urutan berat
            // hanya dipakai sebagai penyelamat bila jalur bersih gagal.
            Thread.sleep(150)
            Log.i(TAG, "[PTP] Tahap 1 — handshake bersih (tanpa device reset)")
            if (initPtpSession(gentle = true)) return true

            Log.w(TAG, "[PTP] Tahap 1 gagal. Tahap 2 — device reset + pembersihan penuh...")

            Log.i(TAG, "🔧 Mengirim PTP Device Reset (USB Class Request 0x66)...")
            try {
                val resetResult = conn.controlTransfer(
                    0x21,       // bmRequestType: Host-to-Device, Class, Interface
                    0x66,       // bRequest: Device Reset (Still Image Capture Class / ISO 15740)
                    0,          // wValue: 0
                    finalIf.id, // wIndex: interface number
                    null, 0,    // no data
                    3000        // timeout 3 detik
                )
                Log.i(TAG, "   PTP Device Reset result: $resetResult (0=OK)")
            } catch (e: Exception) {
                Log.w(TAG, "   PTP Device Reset exception (non-fatal): ${e.message}")
            }

            // Kamera Sony butuh waktu cukup lama setelah device reset.
            Thread.sleep(1500)

            try {
                clearEndpointHalt(epIn)
                clearEndpointHalt(epOut)
                if (epInt != null) clearEndpointHalt(epInt)
            } catch (_: Exception) {}

            Thread.sleep(300)
            drainEndpoints()
            Thread.sleep(200)

            return initPtpSession(gentle = false)

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
                try {
                    sendPtpCommand(PTP_OP_CLOSE_SESSION, listOf(1))
                } catch (_: Exception) {
                    Log.d(TAG, "CloseSession gagal (pipe mungkin stalled), lanjut close.")
                }
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
            isRemoteReady = false
            transactionId = 1
        }
    }

    // ─── 4. PTP Protocol & Handshake ───────────────────────────────────────────

    /**
     * Membuka sesi PTP.
     *
     * @param gentle true = langsung OpenSession tanpa CloseSession pendahuluan.
     *   CloseSession pada koneksi baru (belum ada sesi) adalah perintah yang
     *   tidak diminta protokol dan pada Sony bisa membuat kamera berhenti
     *   menjawab. Jalur ini dicoba lebih dulu.
     */
    private fun initPtpSession(gentle: Boolean = false): Boolean {
        transactionId = 1

        if (!gentle) {
            // Bersihkan sesi lama yang mungkin menggantung dari app lain/crash.
            Log.i(TAG, "PTP -> CloseSession pendahuluan (membersihkan sesi lama)...")
            try {
                sendPtpCommand(PTP_OP_CLOSE_SESSION, listOf(1), explicitTid = 0)
            } catch (_: Exception) {
                Log.d(TAG, "   CloseSession awal gagal (normal jika belum ada sesi).")
            }
            Thread.sleep(200)
            try {
                endpointIn?.let { clearEndpointHalt(it) }
                endpointOut?.let { clearEndpointHalt(it) }
            } catch (_: Exception) {}
            drainEndpoints()
            Thread.sleep(200)
            transactionId = 1
        }

        // ─── PROBE: GetDeviceInfo (0x1001) ───
        // Perintah standar PTP yang sah TANPA sesi terbuka. Ini memisahkan dua
        // penyebab yang selama ini tampak identik:
        //   - probe menjawab  → transport USB sehat, masalahnya di sesi/mode
        //   - probe bisu juga → masalahnya di lapisan USB (kabel/daya/driver)
        Log.i(TAG, "[PTP] Probe GetDeviceInfo (0x1001)...")
        val probe = sendPtpCommand(PTP_OP_GET_DEVICE_INFO, emptyList(), explicitTid = 0)
        val probeCode = probe.responseCode.toInt() and 0xFFFF
        if (probeCode == 0 && probe.data == null) {
            Log.e(TAG, "[PTP] Probe BISU — kamera tidak menjawab perintah PTP paling dasar.")
            Log.e(TAG, "      Ini masalah lapisan USB (kabel data / daya / driver), " +
                "BUKAN mode PC Remote.")
        } else {
            Log.i(TAG, "[PTP] Probe MENJAWAB (0x${String.format("%04X", probeCode)}, " +
                "${probe.data?.size ?: 0} bytes data) — transport USB sehat.")
        }
        Thread.sleep(150)
        transactionId = 1

        // 1. Standar PTP OpenSession (SessionID=1, TransactionID=0 per PTP spec)
        Log.i(TAG, "PTP -> Mengirim OpenSession (0x1002, SessionID=1, TID=0)...")
        var respOpen = sendPtpCommand(PTP_OP_OPEN_SESSION, listOf(1), explicitTid = 0)

        // Pada jalur bersih, satu kali percobaan sudah cukup untuk menilai.
        // Retry berat hanya dilakukan pada tahap 2.
        if (!gentle && respOpen.responseCode.toInt() == 0) {
            Log.w(TAG, "⚠️ OpenSession tidak mendapat respons (0x0). Retry dengan jeda panjang...")
            Thread.sleep(1500)
            try {
                endpointIn?.let { clearEndpointHalt(it) }
                endpointOut?.let { clearEndpointHalt(it) }
            } catch (_: Exception) {}
            drainEndpoints()
            Thread.sleep(500)
            transactionId = 1
            respOpen = sendPtpCommand(PTP_OP_OPEN_SESSION, listOf(1), explicitTid = 0)
        }

        if (respOpen.responseCode == PTP_RC_OK || respOpen.responseCode == PTP_RC_SESSION_ALREADY_OPEN) {
            Log.i(TAG, "✅ PTP OpenSession Berhasil! (Response=0x${String.format("%04X", respOpen.responseCode.toInt() and 0xFFFF)})")
            isSessionOpen = true
        } else {
            val code = String.format("%04X", respOpen.responseCode.toInt() and 0xFFFF)
            if (gentle) {
                Log.w(TAG, "[PTP] Tahap 1: OpenSession 0x$code — coba tahap 2.")
            } else {
                Log.e(TAG, "❌ PTP OpenSession GAGAL (0x$code). Sesi tidak dibuka.")
            }
            isSessionOpen = false
            isRemoteReady = false
            return false
        }

        Thread.sleep(100)

        // 2. Sony SDIO Handshake Phase 1 (0x9201, param1=1, param2=0, param3=0)
        //    Per libgphoto2: harus 3 parameter, bukan 2!
        var sdioSuccess = true
        try {
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 1: param 1,0,0)...")
            val res1 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(1, 0, 0))
            Log.i(TAG, "   Phase 1 Response: 0x${String.format("%04X", res1.responseCode.toInt() and 0xFFFF)}, DataSize=${res1.data?.size ?: 0}")
            if (res1.responseCode != PTP_RC_OK) {
                Log.w(TAG, "⚠️ SDIO Phase 1 gagal (expected 0x2001). Kamera mungkin tidak dalam mode PC Remote.")
                sdioSuccess = false
            }

            Thread.sleep(200)

            // Sony SDIO Handshake Phase 2 (0x9201, param1=2, param2=0, param3=0)
            Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 2: param 2,0,0)...")
            val res2 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(2, 0, 0))
            Log.i(TAG, "   Phase 2 Response: 0x${String.format("%04X", res2.responseCode.toInt() and 0xFFFF)}, DataSize=${res2.data?.size ?: 0}")

            Thread.sleep(200)

            // ─── LANGKAH YANG SELAMA INI HILANG ───
            //
            // Antara Phase 2 dan Phase 3, libgphoto2 memanggil
            // GetSDIOGetExtDeviceInfo (0x9202) dengan parameter 0xC8. Kamera
            // memakai panggilan ini untuk menyerahkan daftar properti vendor
            // yang didukung, dan BARU SETELAH ITU menerima perintah kontrol.
            //
            // Tanpa langkah ini, Phase 3 menjawab 0xA101 dan setiap perintah
            // shutter (0x9207 → 0xD2C1 AF, 0xD2C2 capture) tidak dijawab sama
            // sekali (0x0000) — persis gejala "Kamera menolak perintah AF".
            Log.i(TAG, "[PTP] Sony GetSDIOGetExtDeviceInfo (0x9202, param 0xC8)...")
            try {
                val resInfo = sendPtpCommand(SONY_OP_GET_EXT_DEVICE_INFO, listOf(0xC8))
                Log.i(TAG, "   ExtDeviceInfo Response: 0x${String.format("%04X", resInfo.responseCode.toInt() and 0xFFFF)}, " +
                    "DataSize=${resInfo.data?.size ?: 0}")
            } catch (e: Exception) {
                Log.w(TAG, "   ExtDeviceInfo exception: ${e.message}")
            }

            Thread.sleep(200)

            // Sony SDIO Handshake Phase 3 (0x9201, param1=3, param2=0, param3=0)
            // Phase 3 bisa stall di beberapa kamera Sony — handle gracefully
            try {
                Log.i(TAG, "Sony PTP -> Mengirim SonySDIOConnect (Phase 3: param 3,0,0)...")
                val res3 = sendPtpCommand(SONY_OP_SDIO_CONNECT, listOf(3, 0, 0))
                Log.i(TAG, "   Phase 3 Response: 0x${String.format("%04X", res3.responseCode.toInt() and 0xFFFF)}")
            } catch (e3: Exception) {
                Log.w(TAG, "Phase 3 exception (non-fatal): ${e3.message}")
            }

            // Priming properti: kamera menyiapkan tabel properti vendornya.
            // libgphoto2 memanggil ini sebelum perintah kontrol pertama.
            Thread.sleep(200)
            Log.i(TAG, "[PTP] Sony GetAllExtDevicePropInfo (0x9209)...")
            try {
                val resProps = sendPtpCommand(SONY_OP_GET_ALL_EXT_DEVICE_PROP_INFO)
                Log.i(TAG, "   AllExtDevicePropInfo Response: 0x${String.format("%04X", resProps.responseCode.toInt() and 0xFFFF)}, " +
                    "DataSize=${resProps.data?.size ?: 0}")
            } catch (e: Exception) {
                Log.w(TAG, "   AllExtDevicePropInfo exception: ${e.message}")
            }

            // ─── PENTING: Recovery endpoint setelah SDIO handshake ───
            // Phase 3 sering menyebabkan endpoint stall pada Sony ZV-E10.
            // Harus clear halt KEDUA endpoint + drain sebelum kirim command apapun.
            Log.i(TAG, "🔧 Membersihkan USB pipe setelah SDIO handshake...")
            try {
                endpointIn?.let { clearEndpointHalt(it) }
                endpointOut?.let { clearEndpointHalt(it) }
            } catch (_: Exception) {}
            Thread.sleep(200)
            drainEndpoints()
            Thread.sleep(300)

            if (sdioSuccess) {
                Log.i(TAG, "✅ Sony SDIO Handshake selesai — kamera siap menerima remote control.")
            } else {
                Log.w(TAG, "⚠️ Sony SDIO Handshake DITOLAK kamera.")
                Log.w(TAG, "   → Di kamera set: MENU > Setup > USB > USB Connection = PC Remote")
                Log.w(TAG, "   → lalu: MENU > Network > PC Remote Function > PC Remote = ON")
                Log.w(TAG, "   → Shutter PTP dinonaktifkan; aplikasi memakai frame HDMI.")
            }
            isRemoteReady = sdioSuccess
        } catch (e: Exception) {
            Log.w(TAG, "Sony extension handshake error: ${e.message}")
            isRemoteReady = false
        }

        isSessionOpen = true
        return true
    }

    // ─── 5. Remote Capture & Image Transfer ───────────────────────────────────

    suspend fun capturePhoto(): Map<String, Any?> = withContext(Dispatchers.IO) {
        // BUG LAMA (menyebabkan foto tidak pernah HD):
        // dulu di sini dipanggil findSonyCamera(), yang MEMPRIORITASKAN HDMI
        // capture card. Saat kedua kabel terpasang, cabang isUvcDevice() selalu
        // menang dan fungsi ini langsung return "success = true" TANPA filePath —
        // shutter Sony tidak pernah dijalankan sama sekali. Di sisi Dart, syarat
        // `res.isSuccess && res.filePath != null` gagal, sehingga aplikasi selalu
        // jatuh ke frame-grab HDMI 1920x1080. Itulah kenapa hasilnya terlihat
        // seperti screenshot video, bukan foto 24 MP dari sensor.
        //
        // Sekarang: cari perangkat PTP secara spesifik.
        val dev = findPtpCamera()
        if (dev == null) {
            val uvc = findUvcDevice()
            Log.w(TAG, "📹 Kamera PTP tidak ditemukan; hanya ada " +
                "${uvc?.productName ?: "perangkat non-PTP"}. Shutter mekanik dilewati.")
            return@withContext mapOf(
                "success" to false,
                "isUvc" to (uvc != null),
                "message" to "Kamera Sony (PTP) tidak terdeteksi. Pastikan kabel USB C-to-C " +
                    "tersambung dan USB Connection = PC Remote."
            )
        }

        Log.i(TAG, "[CAMERA] Capture started")
        lastCaptureWidth = 0
        lastCaptureHeight = 0

        // PAKAI ULANG sesi yang sudah ada bila masih sehat.
        //
        // Dulu di sini SELALU closeConnection() + openConnection(), artinya
        // handshake penuh (device reset, OpenSession, 3 fase SDIO) diulang pada
        // SETIAP jepretan — dan itu terjadi saat capture card sedang streaming
        // 1080p30 di hub USB yang sama. Perebutan bus itu membuat pembacaan
        // balasan OpenSession gagal (0x0000) dan seluruh sesi tumbang.
        if (isRemoteControlReady()) {
            Log.i(TAG, "♻️ Memakai ulang sesi PTP yang sudah terbuka.")
        } else {
            Log.i(TAG, "🔄 Sesi belum siap — membuka koneksi fresh...")
            closeConnection()
            delay(800)
            if (!openConnection()) {
                return@withContext mapOf(
                    "success" to false,
                    "message" to "Gagal menghubungkan kamera Sony via USB PTP."
                )
            }
        }

        try {
            // Drain any pending data on endpoints first
            drainEndpoints()
            delay(200)

            // 1. Shutter Press Phase 1: Half-Press (AF-Lock)
            //    Sony Property 0xD2C1, Value 0x0002 = PRESS (per libgphoto2)
            Log.i(TAG, "⚡ S1: Shutter Half-Press (AF-Lock via 0xD2C1 = 0x0002)...")
            val s1Res = sendPtpCommandWithDataOut(SONY_OP_DO_CONTROL, 0xD2C1, byteArrayOf(SONY_SHUTTER_PRESS, 0x00))
            Log.i(TAG, "   S1 (AF) Response: 0x${String.format("%04X", s1Res.responseCode.toInt() and 0xFFFF)}")

            if (s1Res.responseCode != PTP_RC_OK) {
                val errCode = String.format("%04X", s1Res.responseCode.toInt() and 0xFFFF)
                Log.w(TAG, "⚠️ Shutter AF gagal (0x$errCode). Mencoba reconnect sekali lagi...")
                // Retry: tutup, tunggu lebih lama, buka ulang
                closeConnection()
                delay(1500)
                val reopened = openConnection()
                if (reopened) {
                    drainEndpoints()
                    delay(500)
                    Log.i(TAG, "🔄 Retry S1 setelah reconnect...")
                    val retryS1 = sendPtpCommandWithDataOut(SONY_OP_DO_CONTROL, 0xD2C1, byteArrayOf(SONY_SHUTTER_PRESS, 0x00))
                    Log.i(TAG, "   Retry S1 (AF) Response: 0x${String.format("%04X", retryS1.responseCode.toInt() and 0xFFFF)}")
                    if (retryS1.responseCode != PTP_RC_OK) {
                        return@withContext mapOf(
                            "success" to false,
                            "message" to "Kamera menolak perintah AF setelah retry (0x${String.format("%04X", retryS1.responseCode.toInt() and 0xFFFF)}). " +
                                "Pastikan di kamera: MENU → Network → PC Remote = ON, USB Connection = PC Remote."
                        )
                    }
                } else {
                    return@withContext mapOf(
                        "success" to false,
                        "message" to "Gagal reconnect ke kamera setelah shutter ditolak."
                    )
                }
            }

            // Tunggu AF lock selesai
            delay(500)

            // 2. Shutter Press Phase 2: Full-Press (Shutter Release!)
            //    Sony Property 0xD2C2, Value 0x0002 = PRESS
            Log.i(TAG, "⚡ S2: Shutter Full-Press (Take Photo via 0xD2C2 = 0x0002)...")
            val s2Res = sendPtpCommandWithDataOut(SONY_OP_DO_CONTROL, 0xD2C2, byteArrayOf(SONY_SHUTTER_PRESS, 0x00))
            Log.i(TAG, "   S2 (Shutter) Response: 0x${String.format("%04X", s2Res.responseCode.toInt() and 0xFFFF)}")
            delay(300)

            // 3. Shutter Release Off — Value 0x0001 = RELEASE
            Log.i(TAG, "⚡ S0: Shutter Release Off (0xD2C2 = 0x0001)...")
            sendPtpCommandWithDataOut(SONY_OP_DO_CONTROL, 0xD2C2, byteArrayOf(SONY_SHUTTER_RELEASE, 0x00))
            delay(100)

            // AF Release Off — Value 0x0001 = RELEASE
            Log.i(TAG, "⚡ AF Release Off (0xD2C1 = 0x0001)...")
            sendPtpCommandWithDataOut(SONY_OP_DO_CONTROL, 0xD2C1, byteArrayOf(SONY_SHUTTER_RELEASE, 0x00))

            // 4. Tunggu ObjectAdded event (0x4002) dari interrupt endpoint
            //    Kamera butuh waktu menyimpan ke SD card sebelum object tersedia
            Log.i(TAG, "[PTP] Shutter triggered")
            Log.i(TAG, "[PTP] Waiting for image")
            val objectAddedReceived = waitForObjectAddedEvent(timeoutMs = 5000)
            if (!objectAddedReceived) {
                Log.w(TAG, "⚠️ Timeout menunggu ObjectAdded event. Tetap coba download...")
                // Fallback delay jika event tidak terdeteksi
                delay(2000)
            }

            // 5. Download JPEG: Coba via GetObjectHandles dulu, jika kosong fallback ke bulk IN stream
            var capturedFile = downloadLatestImageViaPtp()
            if (capturedFile == null) {
                Log.i(TAG, "Fallback: Membaca JPEG langsung dari USB Bulk IN stream...")
                capturedFile = readCapturedImageFromUsbStream()
            }

            if (capturedFile != null && capturedFile.exists() && capturedFile.length() > 10000) {
                return@withContext mapOf(
                    "success" to true,
                    "filePath" to capturedFile.absolutePath,
                    "fileSizeBytes" to capturedFile.length(),
                    // Dimensi ikut dikirim supaya sisi Dart bisa memverifikasi
                    // sendiri bahwa ini benar foto sensor, bukan frame HDMI.
                    "width" to lastCaptureWidth,
                    "height" to lastCaptureHeight,
                    "message" to "Foto ${lastCaptureWidth}x$lastCaptureHeight " +
                        "(${capturedFile.length() / 1024} KB) dari Sony ZV-E10"
                )
            } else {
                Log.e(TAG, "[CAMERA] Capture FAILED — object tidak berhasil diunduh")
                return@withContext mapOf(
                    "success" to false,
                    "width" to 0,
                    "height" to 0,
                    "message" to "Shutter terpicu namun JPEG gagal ditransfer. " +
                        "Pastikan SD Card terpasang dan ada ruang kosong di kamera."
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
            var drained = 0
            while (conn.bulkTransfer(epIn, buf, buf.size, 50) > 0) { drained++ }
            // Drain interrupt in
            if (epInt != null) {
                while (conn.bulkTransfer(epInt, buf, epInt.maxPacketSize, 50) > 0) { drained++ }
            }
            if (drained > 0) Log.d(TAG, "Drained $drained pending packets from endpoints")
        } catch (_: Exception) {}
    }

    /**
     * Menunggu PTP Event ObjectAdded (0x4002) dari Interrupt Endpoint.
     * Event ini menandakan kamera sudah selesai menyimpan foto ke SD card.
     * Return true jika event diterima, false jika timeout.
     */
    private fun waitForObjectAddedEvent(timeoutMs: Int = 5000): Boolean {
        val conn = usbConnection ?: return false
        val epInt = endpointInt
        val epIn = endpointIn ?: return false

        val startTime = System.currentTimeMillis()
        val buf = ByteArray(512)

        while (System.currentTimeMillis() - startTime < timeoutMs) {
            // Coba baca dari interrupt endpoint dulu (jika ada)
            if (epInt != null) {
                val intRes = conn.bulkTransfer(epInt, buf, buf.size, 300)
                if (intRes >= 12) {
                    val rbb = ByteBuffer.wrap(buf, 0, intRes).order(ByteOrder.LITTLE_ENDIAN)
                    val containerLen = rbb.int
                    val containerType = rbb.short
                    val eventCode = rbb.short
                    Log.d(TAG, "Event received: type=$containerType, code=0x${String.format("%04X", eventCode.toInt() and 0xFFFF)}")
                    if (eventCode == PTP_EC_OBJECT_ADDED) {
                        Log.i(TAG, "✅ ObjectAdded event (0x4002) diterima — foto tersedia di kamera!")
                        return true
                    }
                }
            }

            // Fallback: juga cek bulk endpoint untuk event (beberapa kamera kirim via bulk)
            val bulkRes = conn.bulkTransfer(epIn, buf, buf.size, 200)
            if (bulkRes >= 12) {
                val rbb = ByteBuffer.wrap(buf, 0, bulkRes).order(ByteOrder.LITTLE_ENDIAN)
                val containerLen = rbb.int
                val containerType = rbb.short
                val code = rbb.short
                if (containerType == PTP_CONTAINER_TYPE_EVENT) {
                    Log.d(TAG, "Bulk event: code=0x${String.format("%04X", code.toInt() and 0xFFFF)}")
                    if (code == PTP_EC_OBJECT_ADDED) {
                        Log.i(TAG, "✅ ObjectAdded event (0x4002) via bulk — foto tersedia!")
                        return true
                    }
                }
            }

            Thread.sleep(100)
        }

        return false
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
    /**
     * Membaca dimensi JPEG langsung dari marker SOF, tanpa men-decode gambar.
     *
     * Dipakai untuk MEMBUKTIKAN bahwa foto benar-benar berasal dari sensor
     * Sony (mis. 6000x4000) dan bukan frame HDMI 1920x1080. "Shutter berhasil"
     * tidak sama dengan "foto beresolusi penuh berhasil diunduh".
     *
     * @return Pair(width, height) atau null bila tidak ditemukan.
     */
    private fun readJpegDimensions(bytes: ByteArray): Pair<Int, Int>? {
        try {
            var i = 2 // lewati SOI (FFD8)
            while (i + 9 < bytes.size) {
                if ((bytes[i].toInt() and 0xFF) != 0xFF) { i++; continue }
                val marker = bytes[i + 1].toInt() and 0xFF
                // SOF0..SOF15 kecuali DHT(C4), JPG(C8), DAC(CC)
                if (marker in 0xC0..0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
                    val h = ((bytes[i + 5].toInt() and 0xFF) shl 8) or (bytes[i + 6].toInt() and 0xFF)
                    val w = ((bytes[i + 7].toInt() and 0xFF) shl 8) or (bytes[i + 8].toInt() and 0xFF)
                    return Pair(w, h)
                }
                val segLen = ((bytes[i + 2].toInt() and 0xFF) shl 8) or (bytes[i + 3].toInt() and 0xFF)
                if (segLen <= 0) break
                i += 2 + segLen
            }
        } catch (e: Exception) {
            Log.w(TAG, "readJpegDimensions error: ${e.message}")
        }
        return null
    }

    /** Dimensi foto terakhir yang berhasil diunduh via PTP. */
    private var lastCaptureWidth = 0
    private var lastCaptureHeight = 0

    private fun downloadLatestImageViaPtp(): File? {
        val conn = usbConnection ?: return null

        // 1. GetObjectHandles: param1=0xFFFFFFFF (all storage),
        //    param2=0x00000000 (all formats), param3=0xFFFFFFFF (all objects)
        Log.i(TAG, "[PTP] Waiting for image")
        Log.i(TAG, "[PTP] GetObjectHandles")
        val handlesResp = sendPtpCommand(
            PTP_OP_GET_OBJECT_HANDLES,
            listOf(0xFFFFFFFF.toInt(), 0x00000000, 0xFFFFFFFF.toInt())
        )

        val handlesData = handlesResp.data
        if (handlesData == null || handlesData.size < 4) {
            Log.e(TAG, "[PTP] Object handles empty (data ${handlesData?.size ?: 0} bytes)")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }

        // Parse array of handles: [count(4)] [handle1(4)] [handle2(4)] ...
        val bb = ByteBuffer.wrap(handlesData).order(ByteOrder.LITTLE_ENDIAN)
        val count = bb.int
        Log.i(TAG, "[PTP] Object handles received: $count")

        if (count <= 0) {
            Log.e(TAG, "[PTP] Object handles empty")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }

        // Ambil handle terakhir (foto paling baru)
        val handles = IntArray(count) { bb.int }
        val latestHandle = handles.last()
        Log.i(TAG, "[PTP] Latest JPEG object found: 0x${latestHandle.toString(16)}")

        // 2. GetObject: download JPEG bytes untuk handle ini
        Log.i(TAG, "[PTP] Download started")
        val objectResp = sendPtpCommand(PTP_OP_GET_OBJECT, listOf(latestHandle))

        val jpegBytes = objectResp.data
        if (jpegBytes == null || jpegBytes.size < 10000) {
            Log.e(TAG, "[PTP] Download failed — data ${jpegBytes?.size ?: 0} bytes")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }

        // Verifikasi SOI marker JPEG (0xFF 0xD8)
        if ((jpegBytes[0].toInt() and 0xFF) != 0xFF || (jpegBytes[1].toInt() and 0xFF) != 0xD8) {
            Log.e(TAG, "[PTP] Data bukan JPEG (SOI marker tidak ditemukan)")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }

        Log.i(TAG, "[PTP] Download completed")

        // VALIDASI RESOLUSI — pembeda utama foto sensor vs frame HDMI.
        val dims = readJpegDimensions(jpegBytes)
        if (dims == null) {
            Log.e(TAG, "[PTP] Tidak bisa membaca dimensi JPEG")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }
        lastCaptureWidth = dims.first
        lastCaptureHeight = dims.second

        val mp = (dims.first.toLong() * dims.second) / 1_000_000.0
        Log.i(TAG, "[CAMERA] Image size: ${jpegBytes.size} bytes")
        Log.i(TAG, "[CAMERA] Resolution: ${dims.first} x ${dims.second} " +
            "(${String.format("%.1f", mp)} MP)")

        // Foto sensor Sony jauh di atas 1920x1080. Bila yang datang justru
        // seukuran frame HDMI, berarti sumbernya salah — jangan diloloskan.
        if (dims.first <= 1920 && dims.second <= 1080) {
            Log.e(TAG, "[CAMERA] Resolusi ${dims.first}x${dims.second} setara frame HDMI, " +
                "bukan foto sensor. Ditolak.")
            Log.e(TAG, "[CAMERA] Capture FAILED")
            return null
        }

        // Simpan ke file cache internal
        val photoDir = File(context.cacheDir, "sony_photos")
        if (!photoDir.exists()) photoDir.mkdirs()
        val photoFile = File(photoDir, "sony_capture_${System.currentTimeMillis()}.jpg")
        FileOutputStream(photoFile).use { it.write(jpegBytes) }

        Log.i(TAG, "[CAMERA] Capture SUCCESS — ${photoFile.absolutePath}")
        return photoFile
    }

    private fun readCapturedImageFromUsbStream(): File? {
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
        // Dulu ketiga baris ini keluar DIAM-DIAM dengan responseCode 0x0000,
        // sehingga koneksi yang ditutup oleh proses lain (dua handshake
        // berjalan bersamaan) terbaca persis seperti "kamera tidak menjawab".
        // Sekarang kondisi itu selalu tercatat.
        val conn = usbConnection ?: run {
            Log.e(TAG, "❌ sendPtpCommand 0x${String.format("%04X", opCode.toInt() and 0xFFFF)}: " +
                "usbConnection NULL — koneksi ditutup di tengah jalan (kemungkinan ada proses PTP lain).")
            return PtpResponse(0, null)
        }
        val epOut = endpointOut ?: run {
            Log.e(TAG, "❌ sendPtpCommand: endpointOut NULL — koneksi sudah dilepas.")
            return PtpResponse(0, null)
        }
        val epIn = endpointIn ?: run {
            Log.e(TAG, "❌ sendPtpCommand: endpointIn NULL — koneksi sudah dilepas.")
            return PtpResponse(0, null)
        }

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
        val opHex = String.format("%04X", opCode.toInt() and 0xFFFF)
        var outRes = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 3000)
        if (outRes < 0) {
            Log.w(TAG, "⚠️ Endpoint OUT stalled on 0x$opHex, clearing halt...")
            try {
                clearEndpointHalt(epOut)
                outRes = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 3000)
            } catch (_: Exception) {}
            if (outRes < 0) {
                Log.e(TAG, "❌ Gagal mengirim PTP command 0x$opHex setelah retry.")
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
            val inRes = conn.bulkTransfer(epIn, inBuffer, inBuffer.size, 3000)
            if (inRes < 12) {
                // DIAGNOSTIK: bedakan dua kegagalan yang selama ini tampak sama.
                //   inRes  < 0  → pipa error / endpoint halt (masalah protokol atau bus)
                //   inRes == 0  → kamera diam saja, tidak mengirim apa pun (timeout)
                // Keduanya sebelumnya sama-sama berakhir jadi respons 0x0000
                // sehingga penyebabnya tidak bisa dibedakan dari log.
                if (inRes < 0) {
                    Log.e(TAG, "❌ 0x$opHex: bulk IN error (inRes=$inRes) — pipa bermasalah/halt. " +
                        "OUT terkirim $outRes bytes.")
                    try { clearEndpointHalt(epIn) } catch (_: Exception) {}
                } else {
                    Log.e(TAG, "❌ 0x$opHex: kamera TIDAK menjawab dalam 3 detik " +
                        "(inRes=$inRes, OUT terkirim $outRes/${cmdBytes.size} bytes). " +
                        "Perintah terkirim tapi tidak ada balasan.")
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

    /**
     * Mengirim Command PTP dengan Data Out Container (Type 2) pada Endpoint OUT (0x02),
     * lalu membaca Response Container (Type 3) dari Endpoint IN (0x81).
     *
     * Format ini wajib untuk SonySetControlDeviceProperty (0x9207) seperti Shutter Press & AF Lock.
     */
    private fun sendPtpCommandWithDataOut(opCode: Short, param1: Int, dataPayload: ByteArray): PtpResponse {
        // Sama seperti di sendPtpCommand: jangan gagal diam-diam. Koneksi yang
        // hilang di tengah jalan harus bisa dibedakan dari kamera yang bisu.
        val conn = usbConnection ?: run {
            Log.e(TAG, "❌ sendPtpCommandWithDataOut: usbConnection NULL — koneksi ditutup di tengah jalan.")
            return PtpResponse(0, null)
        }
        val epOut = endpointOut ?: run {
            Log.e(TAG, "❌ sendPtpCommandWithDataOut: endpointOut NULL.")
            return PtpResponse(0, null)
        }
        val epIn = endpointIn ?: run {
            Log.e(TAG, "❌ sendPtpCommandWithDataOut: endpointIn NULL.")
            return PtpResponse(0, null)
        }

        val tid = transactionId++

        // 1. Command Container (Type 1) -> 16 bytes (Header 12 bytes + Param1 4 bytes)
        val cmdLen = 16
        val cmdBb = ByteBuffer.allocate(cmdLen).order(ByteOrder.LITTLE_ENDIAN)
        cmdBb.putInt(cmdLen)
        cmdBb.putShort(PTP_CONTAINER_TYPE_COMMAND) // = 1
        cmdBb.putShort(opCode)
        cmdBb.putInt(tid)
        cmdBb.putInt(param1)

        val cmdBytes = cmdBb.array()
        val opCodeHex = String.format("%04X", opCode.toInt() and 0xFFFF)
        var out1 = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 2000)
        if (out1 < 0) {
            Log.w(TAG, "⚠️ sendPtpCommandWithDataOut: Endpoint OUT stalled on cmd 0x$opCodeHex, clearing halt...")
            try {
                clearEndpointHalt(epOut)
                clearEndpointHalt(epIn)  // Clear IN juga untuk reset pipe
                Thread.sleep(100)
                out1 = conn.bulkTransfer(epOut, cmdBytes, cmdBytes.size, 2000)
            } catch (_: Exception) {}
            if (out1 < 0) {
                Log.e(TAG, "❌ Gagal kirim cmd container 0x$opCodeHex")
                return PtpResponse(0, null)
            }
        }

        // 2. Data Out Container (Type 2) -> 12 bytes Header + Payload bytes
        val dataLen = 12 + dataPayload.size
        val dataBb = ByteBuffer.allocate(dataLen).order(ByteOrder.LITTLE_ENDIAN)
        dataBb.putInt(dataLen)
        dataBb.putShort(PTP_CONTAINER_TYPE_DATA) // = 2
        dataBb.putShort(opCode)
        dataBb.putInt(tid)
        dataBb.put(dataPayload)

        val dataBytes = dataBb.array()
        var out2 = conn.bulkTransfer(epOut, dataBytes, dataBytes.size, 2000)
        if (out2 < 0) {
            Log.w(TAG, "⚠️ sendPtpCommandWithDataOut: Endpoint OUT stalled on data 0x$opCodeHex, clearing halt...")
            try {
                clearEndpointHalt(epOut)
                Thread.sleep(100)
                out2 = conn.bulkTransfer(epOut, dataBytes, dataBytes.size, 2000)
            } catch (_: Exception) {}
            if (out2 < 0) {
                Log.e(TAG, "❌ Gagal kirim data out container 0x$opCodeHex")
                return PtpResponse(0, null)
            }
        }

        // 3. Response Container (Type 3) from Endpoint IN (0x81)
        val respBuffer = ByteArray(512)
        val inRes = conn.bulkTransfer(epIn, respBuffer, respBuffer.size, 2000)
        if (inRes >= 12) {
            val rbb = ByteBuffer.wrap(respBuffer, 0, inRes).order(ByteOrder.LITTLE_ENDIAN)
            val rLen = rbb.int
            val rType = rbb.short
            val rCode = rbb.short
            return PtpResponse(rCode, null)
        } else if (inRes < 0) {
            try { clearEndpointHalt(epIn) } catch (_: Exception) {}
        }

        return PtpResponse(0, null)
    }
}
