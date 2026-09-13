import 'package:flutter/services.dart';

/// Thin wrapper around the native SMS capture method channel.
///
/// The native side owns the silent broadcast receiver + pending queue;
/// everything Flutter needs to read/write it goes through these calls.
class SmsCaptureService {
  SmsCaptureService._();

  static const MethodChannel _channel = MethodChannel('moneygrow/sms_capture');

  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('smsCaptureSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 'granted', 'denied' (or 'permanently_denied' folded into denied).
  static Future<String> permissionStatus() async {
    try {
      return await _channel.invokeMethod<String>('permissionStatus') ?? 'denied';
    } catch (_) {
      return 'denied';
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enables/disables silent background capture on the native receiver.
  static Future<bool> setCaptureEnabled(bool enabled) async {
    try {
      return await _channel
              .invokeMethod<bool>('setCaptureEnabled', {'enabled': enabled}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Pushes the sender whitelist used by the native receiver's sender gate.
  static Future<bool> setSenderWhitelist(List<String> senders) async {
    try {
      return await _channel.invokeMethod<bool>(
              'setSenderWhitelist', {'senders': senders}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Raw messages queued by the receiver while the app was not importing.
  static Future<List<Map<String, dynamic>>> getPendingCaptures() async {
    try {
      final result =
          await _channel.invokeListMethod<Map<dynamic, dynamic>>(
              'getPendingCaptures');
      if (result == null) return [];
      return result.map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearPendingCaptures() async {
    try {
      await _channel.invokeMethod<void>('clearPendingCaptures');
    } catch (_) {}
  }

  /// Scans the SMS inbox for messages from whitelisted senders after [since]
  /// (epoch millis). Requires READ_SMS.
  static Future<List<Map<String, dynamic>>> scanInboxSince(
      DateTime since) async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'scanInboxSince',
        {'since': since.millisecondsSinceEpoch},
      );
      if (result == null) return [];
      return result.map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Distinct SMS inbox senders with message counts, most frequent first.
  /// Used to auto-detect banks and fill the whitelist. Requires READ_SMS.
  static Future<List<Map<String, dynamic>>> discoverSenders() async {
    try {
      final result = await _channel
          .invokeListMethod<Map<dynamic, dynamic>>('discoverSenders');
      if (result == null) return [];
      return result.map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Recent SMS from the whole inbox (any sender), newest first, capped at
  /// [limit]. Used by the message-view screen to show bank messages plus the
  /// senders that are filtered out. Requires READ_SMS.
  static Future<List<Map<String, dynamic>>> getRecentMessages({
    DateTime? since,
    int limit = 200,
  }) async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'getRecentMessages',
        {
          'since': (since ?? DateTime.now().subtract(const Duration(days: 7)))
              .millisecondsSinceEpoch,
          'limit': limit,
        },
      );
      if (result == null) return [];
      return result.map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }
}