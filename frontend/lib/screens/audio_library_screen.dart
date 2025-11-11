import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../services/api_service.dart';

class AudioLibraryScreen extends StatefulWidget {
  final int? sessionId; // Optional - if provided, allows selecting audio for session

  const AudioLibraryScreen({
    super.key,
    this.sessionId,
  });

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<Map<String, dynamic>> _audioFiles = [];
  bool _isLoading = true;
  bool _isUploading = false;
  int? _playingAudioId;
  int? _selectedAudioId; // Currently selected for session playback
  bool _ttsEnabled = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return; // CHECK MOUNTED
      setState(() => _playingAudioId = null);
      _speakIfEnabled("Playback finished");
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return; // CHECK MOUNTED
      if (state == PlayerState.stopped) {
        setState(() => _playingAudioId = null);
      }
    });
  }

  Future<void> _loadAudioFiles() async {
    if (!mounted) return; // CHECK MOUNTED AT START
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.get('/audio/list', useAuth: true);
      
      if (result != null) {
        if (!mounted) return; // CHECK BEFORE setState
        setState(() {
          if (result is List) {
            _audioFiles = result.cast<Map<String, dynamic>>();
          } else if (result is Map && result.containsKey('files')) {
            _audioFiles = (result['files'] as List).cast<Map<String, dynamic>>();
          }
        });
        
        await _speakIfEnabled("Loaded ${_audioFiles.length} audio files");
      }
    } catch (e) {
      print('[AUDIO LIBRARY] Error loading files: $e');
      _showError("Failed to load audio files");
    } finally {
      if (!mounted) return; // CHECK BEFORE setState
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAudioFile() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      // Show upload dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upload Audio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('File: ${file.name}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performUpload(file, _titleController.text, _descriptionController.text);
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      );

    } catch (e) {
      print('[UPLOAD] Error: $e');
      _showError("Failed to pick file");
    }
  }

  Future<void> _performUpload(PlatformFile file, String title, String description) async {
    if (title.trim().isEmpty) {
      _showError("Title is required");
      return;
    }

    setState(() => _isUploading = true);
    await _speakIfEnabled("Uploading audio file");

    try {
      final headers = await ApiService.getHeaders();
      final uri = Uri.parse('http://127.0.0.1:8000/audio/upload?user_id=${await _getUserId()}');
      
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      request.fields['title'] = title;
      request.fields['description'] = description;

      // Determine MIME type from file extension
      String contentType = 'audio/mpeg'; // Default
      final extension = file.extension?.toLowerCase() ?? '';
      
      switch (extension) {
        case 'mp3':
          contentType = 'audio/mpeg';
          break;
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'm4a':
          contentType = 'audio/x-m4a';
          break;
        case 'mp4':
          contentType = 'audio/mp4';
          break;
        case 'ogg':
          contentType = 'audio/ogg';
          break;
        case 'webm':
          contentType = 'audio/webm';
          break;
        default:
          
      }

      print('[UPLOAD] File: ${file.name}');
      print('[UPLOAD] Extension: $extension');
      print('[UPLOAD] Content-Type: $contentType');

      // Handle file based on platform
      if (kIsWeb) {
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
            contentType: MediaType.parse(contentType),
          ));
        }
      } else {
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            file.path!,
            filename: file.name,
            contentType: MediaType.parse(contentType),
          ));
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _speakIfEnabled("Upload successful");
        _titleController.clear();
        _descriptionController.clear();
        await _loadAudioFiles();
      } else {
        print('[UPLOAD] Error: ${response.statusCode} $responseBody');
        _showError("Upload failed: ${jsonDecode(responseBody)['detail'] ?? 'Unknown error'}");
      }
    } catch (e) {
      print('[UPLOAD] Error: $e');
      _showError("Upload failed: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<int?> _getUserId() async {
    // Get from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> _playAudioLocally(int audioId, String title) async {
    try {
      if (_playingAudioId == audioId) {
        await _audioPlayer.stop();
        setState(() => _playingAudioId = null);
        await _speakIfEnabled("Stopped playback");
        return;
      }

      await _audioPlayer.stop();
      final url = 'http://127.0.0.1:8000/audio/$audioId/stream';
      await _audioPlayer.play(UrlSource(url));
      
      setState(() => _playingAudioId = audioId);
      await _speakIfEnabled("Playing $title");
    } catch (e) {
      print('[PLAY] Error: $e');
      _showError("Failed to play audio");
    }
  }

  Future<void> _selectForSession(int audioId, String title) async {
    if (widget.sessionId == null) {
      _showError("No active session");
      return;
    }

    try {
      final result = await ApiService.selectAudio(widget.sessionId!, audioId);

      if (result != null && result['ok'] == true) {
        setState(() => _selectedAudioId = audioId);
        await _speakIfEnabled("Selected $title for session");
        
        // Ask if they want to play immediately
        final play = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Audio Selected'),
            content: Text('Do you want to start playing "$title" for all participants now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Play Now'),
              ),
            ],
          ),
        );

        if (play == true) {
          await _playForSession(audioId);
        }
      } else {
        _showError("Failed to select audio");
      }
    } catch (e) {
      print('[SELECT] Error: $e');
      _showError("Failed to select audio");
    }
  }

  Future<void> _playForSession(int audioId) async {
    if (widget.sessionId == null) return;

    try {
      final result = await ApiService.playAudio(
        widget.sessionId!,
        audioId: audioId,
        speed: 1.0,
      );

      if (result != null && result['ok'] == true) {
        await _speakIfEnabled("Started playback for all participants");
      } else {
        _showError("Failed to start playback");
      }
    } catch (e) {
      print('[PLAY SESSION] Error: $e');
      _showError("Failed to start playback");
    }
  }

  Future<void> _pauseSessionAudio() async {
    if (widget.sessionId == null) return;

    try {
      final result = await ApiService.pauseAudio(widget.sessionId!);

      if (result != null && result['ok'] == true) {
        await _speakIfEnabled("Paused session audio");
      }
    } catch (e) {
      print('[PAUSE] Error: $e');
      _showError("Failed to pause audio");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    _speakIfEnabled(message);
  }

  Future<void> _speakIfEnabled(String text) async {
    if (_ttsEnabled) {
      try {
        await _tts.speak(text);
      } catch (e) {
        print('[TTS] Error: $e');
      }
    }
  }

  @override
  void dispose() {
    // Cancel any pending operations
    _titleController.dispose();
    _descriptionController.dispose();
    
    // Stop and dispose audio player BEFORE disposing
    _audioPlayer.stop();
    _audioPlayer.dispose();
    
    // Stop TTS
    _tts.stop();
    
    // Call super.dispose last
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionId != null 
          ? 'Audio Library - Session ${widget.sessionId}'
          : 'Audio Library'
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Toggle TTS',
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              _speakIfEnabled(_ttsEnabled ? "TTS enabled" : "TTS disabled");
            },
          ),
          if (widget.sessionId != null)
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: 'Pause Session Audio',
              onPressed: _pauseSessionAudio,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                if (_isUploading)
                  const LinearProgressIndicator(),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadAudioFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload New Audio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_audioFiles.length} Audio Files',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Expanded(
                  child: _audioFiles.isEmpty
                      ? const Center(
                          child: Text(
                            'No audio files yet.\nUpload some to get started!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _audioFiles.length,
                          itemBuilder: (context, index) {
                            final audio = _audioFiles[index];
                            final audioId = audio['audio_id'] ?? audio['id'];
                            final title = audio['title'] ?? 'Untitled';
                            final description = audio['description'] ?? '';
                            final uploadedAt = audio['uploaded_at'] ?? '';
                            final isPlaying = _playingAudioId == audioId;
                            final isSelected = _selectedAudioId == audioId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isSelected ? 4 : 2,
                              color: isSelected ? Colors.teal.shade50 : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isPlaying ? Icons.music_note : Icons.audiotrack,
                                          color: isPlaying ? Colors.green : Colors.teal,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.teal,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Text(
                                                        'SELECTED',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (description.isNotEmpty)
                                                Text(
                                                  description,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    if (uploadedAt.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8, left: 44),
                                        child: Text(
                                          'Uploaded: $uploadedAt',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                    
                                    const SizedBox(height: 12),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => _playAudioLocally(audioId, title),
                                          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                                          label: Text(isPlaying ? 'Stop' : 'Preview'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isPlaying ? Colors.orange : Colors.blue,
                                          ),
                                        ),
                                        
                                        if (widget.sessionId != null) ...[
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _selectForSession(audioId, title),
                                            icon: const Icon(Icons.check_circle),
                                            label: const Text('Select & Play'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSelected ? Colors.teal : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
