import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
// import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class InviteStudentsScreen extends StatefulWidget {
  final int sessionId;
  final String sessionTitle;

  const InviteStudentsScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  State<InviteStudentsScreen> createState() => _InviteStudentsScreenState();
}

class _InviteStudentsScreenState extends State<InviteStudentsScreen> {
  final FlutterTts _tts = FlutterTts();
  
  List<Map<String, dynamic>> _students = [];
  Set<int> _invitedStudents = {};
  bool _isLoading = true;
  bool _ttsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.get('/users/students', useAuth: true);
      
      if (result != null) {
        setState(() {
          if (result is List) {
            _students = result.cast<Map<String, dynamic>>();
          }
        });
        
        await _speakIfEnabled("Loaded ${_students.length} students");
      }
    } catch (e) {
      print('[INVITE] Error loading students: $e');
      _showError("Failed to load students");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteStudent(int studentId, String studentName) async {
    try {
      // Use ApiService for consistency
      final result = await ApiService.inviteStudent(widget.sessionId, studentId);

      if (result != null && result['ok'] == true) {
        setState(() => _invitedStudents.add(studentId));
        await _speakIfEnabled("Invited $studentName");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invited $studentName to join session'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showError("Failed to invite $studentName");
      }
    } catch (e) {
      print('[INVITE] Error: $e');
      _showError("Failed to invite $studentName");
    }
  }

  Future<void> _inviteAll() async {
    for (var student in _students) {
      final studentId = student['user_id'] as int;
      if (!_invitedStudents.contains(studentId)) {
        await _inviteStudent(studentId, student['name']);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    await _speakIfEnabled("Invited all students");
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Students'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Toggle TTS',
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Session info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inviting students to:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.sessionTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_invitedStudents.length} of ${_students.length} invited',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Invite all button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _students.length == _invitedStudents.length
                          ? null
                          : _inviteAll,
                      icon: const Icon(Icons.send),
                      label: const Text('Invite All Students'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ),
                
                const Divider(),
                
                // Student list
                Expanded(
                  child: _students.isEmpty
                      ? const Center(
                          child: Text(
                            'No students found',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            final studentId = student['user_id'] as int;
                            final name = student['name'] as String;
                            final phone = student['phone_number'] as String;
                            final isInvited = _invitedStudents.contains(studentId);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isInvited ? 1 : 2,
                              color: isInvited ? Colors.green.shade50 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isInvited ? Colors.green : Colors.teal,
                                  child: Icon(
                                    isInvited ? Icons.check : Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isInvited ? Colors.green.shade700 : null,
                                  ),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: TextStyle(
                                    color: isInvited ? Colors.green.shade600 : Colors.grey,
                                  ),
                                ),
                                trailing: isInvited
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'INVITED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () => _inviteStudent(studentId, name),
                                        icon: const Icon(Icons.send, size: 18),
                                        label: const Text('Invite'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                        ),
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