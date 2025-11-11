import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import 'session_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final sessionCtrl = TextEditingController();
  List sessions = [];
  int? currentUserId;
  String? currentUserName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final name = prefs.getString('user_name') ?? prefs.getString('name') ?? 'Student $id';
    
    setState(() {
      currentUserId = id;
      currentUserName = name;
    });

    if (currentUserId != null) await _loadSessions();

    setState(() => isLoading = false);
  }

  // Fetch active sessions from backend
  Future<void> _loadSessions() async {
    final res = await ApiService.get('/sessions/active', useAuth: true);
    if (res != null && res is List) {
      setState(() => sessions = res);
    }
  }

  // Join a session using form data
  Future<void> joinSession(int sessionId) async {
    if (currentUserId == null) {
      TtsService.speak("User not logged in");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first")),
      );
      return;
    }

    if (currentUserName == null) {
      TtsService.speak("User name not found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User name not found. Please log in again.")),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Construct URL
      final uri = Uri.parse(ApiService.devMode
          ? '${ApiService.baseUrl}/sessions/$sessionId/join?user_id=$currentUserId'
          : '${ApiService.baseUrl}/sessions/$sessionId/join');

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (!ApiService.devMode && token != null)
            'Authorization': 'Bearer $token',
        },
        body: {
          'user_id': currentUserId.toString(), // Must be a string for Form(...)
        },
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        TtsService.speak("Joined session $sessionId");

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionScreen(
                sessionId: sessionId,
                userId: currentUserId!,
                userName: currentUserName!,
                isTeacher: false,
              ),
            ),
          ).then((_) {
            // Refresh sessions when returning
            _loadSessions();
          });
        }
      } else {
        TtsService.speak("Failed to join session");
        debugPrint("Join failed: ${res.statusCode} -> ${res.body}");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to join session: ${res.statusCode}")),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      TtsService.speak("Error joining session");
      debugPrint("Join session error: $e");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  void dispose() {
    sessionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Dashboard"),
        backgroundColor: Colors.teal,
        actions: [
          if (currentUserName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  currentUserName!,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Sessions",
            onPressed: () {
              TtsService.speak("Refreshing sessions");
              _loadSessions();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, ${currentUserName ?? 'Student'}!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "User ID: $currentUserId",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Manual join section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Join Session by ID",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sessionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Session ID",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.meeting_room),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final idText = sessionCtrl.text.trim();
                            if (idText.isEmpty) {
                              TtsService.speak("Please enter a session ID");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please enter a session ID"),
                                ),
                              );
                              return;
                            }
                            
                            final sessionId = int.tryParse(idText);
                            if (sessionId == null) {
                              TtsService.speak("Invalid session ID");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please enter a valid number"),
                                ),
                              );
                              return;
                            }
                            
                            joinSession(sessionId);
                          },
                          icon: const Icon(Icons.login),
                          label: const Text("Join"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Active sessions header
            Row(
              children: [
                const Text(
                  "Active Sessions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                if (sessions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${sessions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Active sessions list
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No active sessions available",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loadSessions,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Refresh"),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, i) {
                          final s = sessions[i];
                          final sessionId = s['session_id'] ?? 0;
                          final title = s['title'] ?? 'Untitled Session';
                          final teacherName = s['teacher_name'] ?? 'Unknown';
                          final participantCount = s['participant_count'] ?? 0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: Text(
                                  '$sessionId',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16),
                                      const SizedBox(width: 4),
                                      Text('Teacher: $teacherName'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.people, size: 16),
                                      const SizedBox(width: 4),
                                      Text('$participantCount participants'),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () => joinSession(sessionId),
                                icon: const Icon(Icons.login, size: 18),
                                label: const Text("Join"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}