import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RtcService {
  final int sessionId;
  final int userId;
  late WebSocketChannel _ws;
  final Map<int, RTCPeerConnection> _peers = {};
  final Map<int, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  final _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  final FlutterTts _tts = FlutterTts();

  RtcService({required this.sessionId, required this.userId});

  Future<void> init() async {
    // Initialize local media
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // Connect WebSocket
    _ws = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/sessions/$sessionId?user_id=$userId'),
    );

    // Listen for messages
    _ws.stream.listen(
      (event) {
        final data = jsonDecode(event);
        _onWsMessage(data); // <--- FIX: this method handles incoming WS events
      },
      onDone: () => _tts.speak("Connection closed."),
      onError: (e) => _tts.speak("Network error"),
    );

    _tts.speak("Connected to session $sessionId");
  }

  MediaStream? get localStream => _localStream;

  // ---------------------------------------------------------------------
  // ✅ Handle WebSocket Messages
  // ---------------------------------------------------------------------
  void _onWsMessage(Map<String, dynamic> data) async {
    final event = data['event'];
    switch (event) {
      case 'joined':
        final pid = data['participant_id'];
        _tts.speak("Participant $pid joined.");
        await _createPeer(pid);
        break;

      case 'left':
        final pid = data['participant_id'];
        _tts.speak("Participant $pid left.");
        _closePeer(pid);
        break;

      case 'mute_changed':
        final pid = data['participant_id'];
        final muted = data['muted'];
        _tts.speak("Participant $pid is now ${muted ? 'muted' : 'unmuted'}");
        break;

      case 'chat':
        final msg = data['message'];
        _tts.speak("Message: $msg");
        break;

      case 'audio_play':
        final audioId = data['audio_id'];
        _tts.speak("Teacher started playing audio $audioId");
        // Optional: trigger synced playback here
        break;

      default:
        print('Unhandled WS event: $data');
    }
  }

  // ---------------------------------------------------------------------
  // ✅ Peer Connection Management
  // ---------------------------------------------------------------------

  Future<void> _createPeer(int remoteId) async {
    if (_peers.containsKey(remoteId)) return;

    final pc = await createPeerConnection(_rtcConfig);
    _peers[remoteId] = pc;

    // Add local stream to connection
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    // Handle remote stream
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[remoteId] = event.streams[0];
        _tts.speak("Audio stream started for participant $remoteId");
      }
    };

    // Handle ICE
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _ws.sink.add(jsonEncode({
        'type': 'ice',
        'to': remoteId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      }));
    };

    // Create offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _ws.sink.add(jsonEncode({
      'type': 'offer',
      'to': remoteId,
      'from': userId,
      'sdp': offer.sdp,
    }));
  }

  void _closePeer(int remoteId) {
    final pc = _peers.remove(remoteId);
    final stream = _remoteStreams.remove(remoteId);
    stream?.dispose();
    pc?.close();
  }

  // ---------------------------------------------------------------------
  // ✅ Cleanup
  // ---------------------------------------------------------------------
  Future<void> dispose() async {
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
    _remoteStreams.clear();
    await _localStream?.dispose();
    await _tts.speak("Disconnected");
    _ws.sink.close();
  }

  void sendChatMessage(String text) {
  _ws.sink.add(jsonEncode({
    'type': 'chat',
    'message': text,
    'from': userId,
  }));
}

}
