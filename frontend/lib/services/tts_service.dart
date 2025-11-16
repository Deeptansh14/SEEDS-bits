// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;
  static bool _enabled = true;

  /// Initialize TTS with default settings
  static Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  /// Speak text if TTS is enabled
  static Future<void> speak(String text) async {
    if (!_enabled) return;

    await init();
    await _tts.speak(text);
  }

  /// Stop current speech
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// Enable or disable TTS
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Check if TTS is enabled
  static bool get isEnabled => _enabled;

  /// Set speech rate (0.0 to 1.0)
  static Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  /// Set volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  /// Set pitch (0.5 to 2.0)
  static Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  /// Get available languages
  static Future<List<dynamic>> getLanguages() async {
    await init();
    return await _tts.getLanguages;
  }

  /// Set language
  static Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }
}