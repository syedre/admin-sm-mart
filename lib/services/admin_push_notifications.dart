import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OrderNotificationHandler = void Function(String orderId, String orderNumber);

class AdminPushNotifications {
  AdminPushNotifications._();

  static const _projectId = 'sm-delivery-app-10f03';
  static const _senderId = '787045272354';
  static const _androidAppId = '1:787045272354:android:565d92c10771b2c2d2f37b';
  static const _iosAppId = '1:787045272354:ios:cac0e73838c0f899d2f37b';
  static const _androidApiKey = 'AIzaSyBUvMNU_X_K5H3_OEFnaQbCXdKKbW6L3wE';
  static const _iosApiKey = 'AIzaSyD8qx3g4GwtG71v71QtmfXc5d0T0FGb4WI';
  static const _storageBucket = 'sm-delivery-app-10f03.firebasestorage.app';
  static const _channelId = 'sm_mart_orders';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static String _apiBaseUrl = '';
  static OrderNotificationHandler? _orderOpenHandler;
  static Map<String, String>? _pendingOrder;

  static Future<void> initialize({required String apiBaseUrl}) async {
    _apiBaseUrl = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

    final options = Platform.isIOS
        ? const FirebaseOptions(
            apiKey: _iosApiKey,
            appId: _iosAppId,
            messagingSenderId: _senderId,
            projectId: _projectId,
            storageBucket: _storageBucket,
            iosBundleId: 'com.yameentraders.smmartadmin',
          )
        : const FirebaseOptions(
            apiKey: _androidApiKey,
            appId: _androidAppId,
            messagingSenderId: _senderId,
            projectId: _projectId,
            storageBucket: _storageBucket,
          );

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          _dispatchOrder(jsonDecode(raw) as Map<String, dynamic>);
        } catch (error) {
          // Ignore malformed notification payloads rather than blocking app startup.
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'New customer orders',
      description: 'Alerts when a customer places a new SM mart order.',
      importance: Importance.max,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _messageSubscription ??= FirebaseMessaging.onMessage.listen(_showForeground);
    _openedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteOpen);
    _tokenSubscription ??= messaging.onTokenRefresh.listen((_) {
      unawaited(_registerCurrentDevice());
    });

    _authSubscription ??=
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        unawaited(_registerCurrentDevice());
      }
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleRemoteOpen(initialMessage);

    if (Supabase.instance.client.auth.currentSession != null) {
      await _registerCurrentDevice();
    }
  }

  static void setOrderOpenHandler(OrderNotificationHandler? handler) {
    _orderOpenHandler = handler;
    final pending = _pendingOrder;
    if (handler != null && pending != null) {
      _pendingOrder = null;
      handler(pending['orderId']!, pending['orderNumber'] ?? '');
    }
  }

  static Future<void> _registerCurrentDevice() async {
    if (_apiBaseUrl.isEmpty || (!Platform.isAndroid && !Platform.isIOS)) return;
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;
    if (user?.email?.trim().toLowerCase() != 'admin@gmail.com' ||
        session == null) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      // On iOS, Firebase cannot issue an FCM token until iOS has supplied
      // the APNs device token. Give APNs time to register before getToken().
      if (Platform.isIOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 15; attempt++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null || apnsToken.isEmpty) {
          print('SM mart Admin: APNs token is not available; FCM registration will retry later.');
          return;
        }
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _sendToken(
        token: token,
        accessToken: session.accessToken,
        platform: Platform.isIOS ? 'ios' : 'android',
        remove: false,
      );
    } catch (error) {
      // Push setup must never prevent the admin app or sign-in flow from working.
      print('SM mart Admin push-token registration failed: $error');
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    if (_apiBaseUrl.isEmpty) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _sendToken(
        token: token,
        accessToken: session.accessToken,
        platform: Platform.isIOS ? 'ios' : 'android',
        remove: true,
      );
    } catch (error) {
      // Sign-out must remain available even if the push API is unreachable.
    }
  }

  static Future<void> _sendToken({
    required String token,
    required String accessToken,
    required String platform,
    required bool remove,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/admin/push-tokens');
    final response = remove
        ? await http.delete(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': token}),
          )
        : await http.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': token, 'platform': platform}),
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Admin push-token API returned HTTP ${response.statusCode}.',
      );
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'New customer order';
    final body = notification?.body ?? 'A customer has placed a new order.';
    await _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'New customer orders',
          channelDescription:
              'Alerts when a customer places a new SM mart order.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleRemoteOpen(RemoteMessage message) {
    _dispatchOrder(message.data);
  }

  static void _dispatchOrder(Map<String, dynamic> data) {
    if (data['type'] != 'new_order') return;
    final orderId = data['orderId']?.toString() ?? '';
    if (orderId.isEmpty) return;
    final orderNumber = data['orderNumber']?.toString() ?? '';
    final handler = _orderOpenHandler;
    if (handler == null) {
      _pendingOrder = {'orderId': orderId, 'orderNumber': orderNumber};
    } else {
      handler(orderId, orderNumber);
    }
  }
}
