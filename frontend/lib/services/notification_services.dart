import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './api_service.dart';
import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';


class FirebaseConfig {
  // Replace with YOUR actual VAPID key
  static const String webVapidKey = "BOYVjb77moWEwSyBY-HxCkiAFBuNrCncK9oSobRL1TubgfGicL1JOiw_B0Nod74jEbsn-xd5URPyRwj0BNzc7LE";
}


// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('[FCM BG] Handling background message: ${message.messageId}');
  
  // You can process the message here if needed
  // For now, we'll just log it
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  FirebaseMessaging? _messaging;
  bool _initialized = false;
  
  // Callback for when notification is tapped
  Function(Map<String, dynamic>)? onNotificationTap;
  
  // Stream for real-time notifications
  final StreamController<Map<String, dynamic>> _notificationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get notificationStream => 
      _notificationController.stream;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      
      if (kIsWeb) {
        await _initializeWeb();
      } else {
        await _initializeMobile();
      }
      
      _initialized = true;
      print('[NOTIFICATIONS] Initialized successfully');
    } catch (e) {
      print('[NOTIFICATIONS] Initialization error: $e');
    }
  }

  /// Initialize for mobile platforms
  Future<void> _initializeMobile() async {
    _messaging = FirebaseMessaging.instance;

    // Request permission
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[NOTIFICATIONS] User granted permission');
      
      // Get FCM token
      String? token = await _messaging!.getToken();
      print('[NOTIFICATIONS] FCM Token: $token');
      
      if (token != null) {
        // Send token to backend
        await _registerTokenWithBackend(token, 'mobile');
      }
      
      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        print('[NOTIFICATIONS] Token refreshed: $newToken');
        _registerTokenWithBackend(newToken, 'mobile');
      });
      
      // Configure local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Handle notification tap when app was terminated
      _messaging!.getInitialMessage().then((message) {
        if (message != null) {
          _handleNotificationTap(message);
        }
      });
    } else {
      print('[NOTIFICATIONS] Permission denied');
    }
  }

  /// Initialize for web platform
  Future<void> _initializeWeb() async {
    try {
      _messaging = FirebaseMessaging.instance;
      
      // Request permission for web
      NotificationSettings settings = await _messaging!.requestPermission();
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[NOTIFICATIONS] Web notification permission granted');
        
        // Get web FCM token with VAPID key
        // You need to get this from Firebase Console -> Project Settings -> Cloud Messaging
        String? token = await _messaging!.getToken(
          vapidKey: FirebaseConfig.webVapidKey,
        );

        
        if (token != null) {
          print('[NOTIFICATIONS] Web FCM Token: $token');
          await _registerTokenWithBackend(token, 'web');
        }
        
        // Listen for token refresh
        _messaging!.onTokenRefresh.listen((newToken) {
          print('[NOTIFICATIONS] Web token refreshed: $newToken');
          _registerTokenWithBackend(newToken, 'web');
        });
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessageWeb);
        
        // Handle notification tap
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } else {
        print('[NOTIFICATIONS] Web notification permission denied');
      }
    } catch (e) {
      print('[NOTIFICATIONS] Web init error: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token, String deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      
      // Send to backend
      final result = await ApiService.post(
        '/users/fcm-token',
        {'token': token, 'device_type': deviceType},
        useAuth: true,
      );
      
      if (result != null && result['ok'] == true) {
        print('[FCM] Token registered with backend');
      }
    } catch (e) {
      print('[FCM] Error registering token with backend: $e');
    }
  }

  /// Handle foreground message on mobile
  void _handleForegroundMessage(RemoteMessage message) {
    print('[NOTIFICATIONS] Foreground message: ${message.notification?.title}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: message.data,
    );
    
    // Emit to stream
    _notificationController.add(message.data);
  }

  /// Handle foreground message on web
  void _handleForegroundMessageWeb(RemoteMessage message) {
    print('[NOTIFICATIONS] Web foreground message: ${message.notification?.title}');
    
    // Show browser notification (if supported)
    // Note: Browser notifications might not work in foreground depending on browser
    
    // Emit to stream
    _notificationController.add(message.data);
  }

  /// Show local notification (mobile only)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'session_channel',
      'Session Notifications',
      channelDescription: 'Notifications for session invitations and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload != null ? _encodePayload(payload) : null,
    );
  }

  /// Handle notification tap from system tray
  void _handleNotificationTap(RemoteMessage message) {
    print('[NOTIFICATIONS] Notification tapped: ${message.data}');
    
    if (onNotificationTap != null) {
      onNotificationTap!(message.data);
    }
    
    _notificationController.add(message.data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      
      if (onNotificationTap != null) {
        onNotificationTap!(data);
      }
      
      _notificationController.add(data);
    }
  }

  /// Encode payload to string
  String _encodePayload(Map<String, dynamic> payload) {
    return payload.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Decode payload from string
  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (var pair in payload.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  /// Get FCM token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Remove token from backend (call on logout)
  Future<void> removeToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await ApiService.delete('/users/fcm-token?token=$token', useAuth: true);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fcm_token');
      }
    } catch (e) {
      print('[FCM] Error removing token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
  }
}