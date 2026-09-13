package com.example.money_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/**
 * Silent background SMS capture for the Auto Capture feature.
 *
 * This receiver only gates the incoming message against the user's sender
 * whitelist and appends the raw message to a bounded pending queue. All
 * parsing, filtering, and storage happens on the Flutter side (on-device).
 *
 * Personal messages from senders outside the whitelist are never touched.
 */
class SmsCaptureReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return

        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val whitelist = prefs.getStringSet(KEY_WHITELIST, emptySet()) ?: emptySet()
        if (whitelist.isEmpty()) return

        val result = goAsync()
        Thread {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (message in messages) {
                    val sender =
                        message.displayOriginatingAddress ?: message.originatingAddress ?: ""
                    if (!matchesWhitelist(sender, whitelist)) continue
                    appendCapture(prefs, sender, message.messageBody ?: "")
                }
            } catch (t: Throwable) {
                Log.w(TAG, "SMS capture failed", t)
            } finally {
                result.finish()
            }
        }.start()
    }

    private fun matchesWhitelist(sender: String, whitelist: Set<String>): Boolean {
        if (sender.isBlank()) return false
        val normalized = sender.lowercase(Locale.ROOT).trim()
        return whitelist.any {
            val entry = it.lowercase(Locale.ROOT).trim()
            normalized == entry || normalized.contains(entry) || entry.contains(normalized)
        }
    }

    private fun appendCapture(prefs: SharedPreferences, sender: String, body: String) {
        val raw = prefs.getString(KEY_PENDING, null)
        val array = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
        val entry = JSONObject()
            .put("sender", sender)
            .put("body", body)
            .put("date", System.currentTimeMillis())
        array.put(entry)
        while (array.length() > MAX_PENDING) {
            array.remove(0)
        }
        prefs.edit().putString(KEY_PENDING, array.toString()).apply()
    }

    companion object {
        private const val TAG = "SmsCaptureReceiver"
        const val PREFS_NAME = "moneygrow_sms"
        const val KEY_ENABLED = "capture_enabled"
        const val KEY_WHITELIST = "sender_whitelist"
        const val KEY_PENDING = "pending_captures"
        private const val MAX_PENDING = 500

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
}