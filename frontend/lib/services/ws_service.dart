// lib/services/ws_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MsgHandler = void Function(Map);

class WsService {
  WebSocketChannel? _channel;
  String? sessionId;
  String? userId;
  MsgHandler? onMessage; // main handler (e.g., session screen)
  // Small registry for chat handlers
  final List<MsgHandler> _chatHandlers = [];

  void connect(String sessionId_, int userId_, MsgHandler onMsg) {
    sessionId = sessionId_;
    userId = userId_.toString();
    _channel?.sink.close();
    _channel = null;

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/sessions/$sessionId?user_id=$userId'),
    );

    onMessage = onMsg;

    _channel!.stream.listen((event) {
      try {
        final data = jsonDecode(event);
        if (data['type'] == 'chat') {
          for (final h in _chatHandlers) h(data);
        }
        onMessage?.call(data);
      } catch (e) {
        debugPrint("[WS PARSE ERROR] $e");
      }
    }, onDone: () {
      Future.delayed(const Duration(seconds: 2), () {
        if (sessionId != null && userId != null) {
          connect(sessionId!, int.parse(userId!), onMsg);
        }
      });
    }, onError: (e) {
      debugPrint("[WS ERROR] $e");
    });
  }


  void send(Map msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {}
  }

  void close() {
    try {
      _channel?.sink.close();
    } catch (e) {}
  }

  void registerChatHandler(MsgHandler h) {
    _chatHandlers.add(h);
  }

  void unregisterChatHandler(MsgHandler h) {
    _chatHandlers.remove(h);
  }
}
