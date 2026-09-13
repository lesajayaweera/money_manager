package com.example.money_manager

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.util.Locale

class MainActivity : FlutterActivity() {

    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "smsCaptureSupported" -> result.success(true)
                    "permissionStatus" -> result.success(permissionStatus())
                    "requestSmsPermission" -> requestSmsPermission(result)
                    "setCaptureEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        smsPrefs().edit().putBoolean(SmsCaptureReceiver.KEY_ENABLED, enabled).apply()
                        result.success(true)
                    }
                    "setSenderWhitelist" -> {
                        val senders = call.argument<List<String>>("senders") ?: emptyList()
                        smsPrefs()
                            .edit()
                            .putStringSet(SmsCaptureReceiver.KEY_WHITELIST, senders.toSet())
                            .apply()
                        result.success(true)
                    }
                    "getPendingCaptures" -> result.success(getPendingCaptures())
                    "clearPendingCaptures" -> {
                        smsPrefs().edit().remove(SmsCaptureReceiver.KEY_PENDING).apply()
                        result.success(true)
                    }
                    "scanInboxSince" -> {
                        val since = call.argument<Long>("since") ?: 0L
                        result.success(scanInboxSince(since))
                    }
                    "discoverSenders" -> result.success(discoverSenders())
                    "getRecentMessages" -> {
                        val since = call.argument<Long>("since") ?: 0L
                        val limit = call.argument<Int>("limit") ?: 200
                        result.success(getRecentMessages(since, limit))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionResult?.success(granted)
            permissionResult = null
        }
    }

    private fun smsPrefs() = SmsCaptureReceiver.prefs(this)

    private fun permissionStatus(): String {
        val read = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
        val receive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS)
        return if (read == PackageManager.PERMISSION_GRANTED &&
            receive == PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 23) {
            result.success(true)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
            PERMISSION_REQUEST_CODE,
        )
    }

    private fun getPendingCaptures(): List<Map<String, Any>> {
        val raw = smsPrefs().getString(SmsCaptureReceiver.KEY_PENDING, null)
        val list = mutableListOf<Map<String, Any>>()
        if (raw.isNullOrBlank()) return list
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(
                    mapOf(
                        "sender" to obj.optString("sender", ""),
                        "body" to obj.optString("body", ""),
                        "date" to obj.optLong("date", 0L),
                    ),
                )
            }
        } catch (_: Throwable) {
            // Corrupt queue — ignore and let the caller retry.
        }
        return list
    }

    private fun scanInboxSince(since: Long): List<Map<String, Any>> {
        val whitelist =
            smsPrefs().getStringSet(SmsCaptureReceiver.KEY_WHITELIST, emptySet()) ?: emptySet()
        if (whitelist.isEmpty()) return emptyList()

        val list = mutableListOf<Map<String, Any>>()
        try {
            val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
            )
            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} ASC",
            )
            cursor?.use { c ->
                while (c.moveToNext()) {
                    val address =
                        c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                    if (!matchesWhitelist(address, whitelist)) continue
                    val id = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms._ID))
                    val body = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                    val date = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    list.add(
                        mapOf("id" to id, "sender" to address, "body" to body, "date" to date),
                    )
                }
            }
        } catch (_: Throwable) {
            // READ_SMS missing or content provider unavailable — return empty.
        }
        return list
    }

    private fun discoverSenders(): List<Map<String, Any>> {
        val counts = LinkedHashMap<String, Int>()
        try {
            val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
            val projection = arrayOf(Telephony.Sms.ADDRESS)
            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${Telephony.Sms.DATE} DESC",
            )
            cursor?.use { c ->
                while (c.moveToNext()) {
                    val address = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                    if (address.isBlank()) continue
                    counts[address] = (counts[address] ?: 0) + 1
                }
            }
        } catch (_: Throwable) {
            // READ_SMS missing or content provider unavailable — return empty.
        }
        return counts.entries
            .sortedByDescending { it.value }
            .map { mapOf("sender" to it.key, "count" to it.value) }
    }

    private fun matchesWhitelist(sender: String, whitelist: Set<String>): Boolean {
        if (sender.isBlank()) return false
        val normalized = sender.lowercase(Locale.ROOT).trim()
        return whitelist.any {
            val entry = it.lowercase(Locale.ROOT).trim()
            normalized == entry || normalized.contains(entry) || entry.contains(normalized)
        }
    }

    /// Recent SMS from the ENTIRE inbox (any sender), newest first, capped at
    /// [limit]. Used by the message-view screen to show bank messages plus
    /// what would otherwise be filtered out. Requires READ_SMS.
    private fun getRecentMessages(since: Long, limit: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (limit <= 0) return list
        try {
            val uri: Uri = Telephony.Sms.Inbox.CONTENT_URI
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
            )
            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} DESC LIMIT $limit",
            )
            cursor?.use { c ->
                while (c.moveToNext()) {
                    val address =
                        c.getString(c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                    val body = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                    val date = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    list.add(mapOf("sender" to address, "body" to body, "date" to date))
                }
            }
        } catch (_: Throwable) {
            // READ_SMS missing or content provider unavailable — return empty.
        }
        return list
    }

    companion object {
        const val CHANNEL_NAME = "moneygrow/sms_capture"
        private const val PERMISSION_REQUEST_CODE = 1001
    }
}