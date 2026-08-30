package com.chenyeju

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.PermissionChecker

/**
 * Manages camera permissions.
 *
 * PATCHED (SnapTechBooth):
 * Upstream v1.0.0 selalu mewajibkan WRITE_EXTERNAL_STORAGE. Pada Android 13
 * (API 33) ke atas permission tersebut sudah dihapus dari sistem dan TIDAK
 * PERNAH bisa di-grant, sehingga hasRequiredPermissions() selalu false dan
 * openUVCCamera() langsung return -> preview hitam + "Permission denied".
 *
 * Patch ini membuat storage permission hanya diwajibkan pada API <= 32.
 */
class PermissionManager {
    companion object {
        private const val TAG = "UVCPermissionManager"
        private const val PERMISSION_REQUEST_CODE = 1230

        /** Storage permission hanya relevan sampai Android 12L (API 32). */
        private val needsLegacyStoragePermission: Boolean
            get() = Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2

        /** Daftar permission yang benar-benar dibutuhkan pada versi Android ini. */
        private fun requiredPermissions(): Array<String> {
            return if (needsLegacyStoragePermission) {
                arrayOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                )
            } else {
                arrayOf(Manifest.permission.CAMERA)
            }
        }

        fun hasRequiredPermissions(context: Context): Boolean {
            val missing = requiredPermissions().filter {
                PermissionChecker.checkSelfPermission(context, it) != PermissionChecker.PERMISSION_GRANTED
            }
            if (missing.isNotEmpty()) {
                Log.w(TAG, "Permission belum diberikan (sdk=${Build.VERSION.SDK_INT}): $missing")
            }
            return missing.isEmpty()
        }

        fun requestPermissionsIfNeeded(activity: Activity?): Boolean {
            if (activity == null) {
                Log.e(TAG, "Activity null - tidak bisa request permission.")
                return false
            }
            if (hasRequiredPermissions(activity)) {
                return true
            }
            ActivityCompat.requestPermissions(
                activity,
                requiredPermissions(),
                PERMISSION_REQUEST_CODE
            )
            return false
        }

        /**
         * PATCHED: hanya menilai permission yang memang wajib. Hasil untuk
         * permission legacy (WRITE_EXTERNAL_STORAGE di API 33+) diabaikan
         * karena sistem selalu mengembalikan PERMISSION_DENIED untuk itu.
         */
        fun isPermissionGranted(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
            if (requestCode != PERMISSION_REQUEST_CODE) return false
            if (grantResults.isEmpty()) return false

            val required = requiredPermissions().toSet()
            var sawRequired = false
            for (i in permissions.indices) {
                if (permissions[i] !in required) continue
                sawRequired = true
                if (grantResults.getOrNull(i) != PackageManager.PERMISSION_GRANTED) {
                    Log.w(TAG, "Permission ditolak user: ${permissions[i]}")
                    return false
                }
            }
            return sawRequired
        }

        fun getPermissionRequestCode() = PERMISSION_REQUEST_CODE
    }
}
