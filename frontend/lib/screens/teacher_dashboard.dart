import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import 'session_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List sessions = [];
  int? currentUserId;
  String? currentUserName;
  bool isLoading = true;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final name = prefs.getString('user_name') ?? prefs.getString('name') ?? 'Teacher $id';
    
    setState(() {
      currentUserId = id;
      currentUserName = name;
    });

    if (currentUserId != null) {
      await _loadSessions();
    }

    setState(() {
      isLoading = false;
    });
  }

  // Fetch all active sessions for this teacher
  Future<void> _loadSessions() async {
    final res = await ApiService.get(
      '/sessions/active',
      useAuth: true,
    );

    if (res != null && res is List) {
      // Filter sessions created by this teacher
      final teacherSessions = res.where((s) => s['created_by'] == currentUserId).toList();
      setState(() {
        sessions = teacherSessions;
      });
    }
  }

  Future<void> createSession() async {
    if (currentUserId == null || currentUserName == null) {
      TtsService.speak("User not logged in");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first")),
      );
      return;
    }

    // Show dialog to get session title
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Session'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Session Title',
            hintText: 'e.g., English Class - Unit 5',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _titleController.text.trim();
              Navigator.pop(context, text.isEmpty ? 'New Session' : text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (title == null) return; // User cancelled

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.post(
      '/sessions',
      {'title': title},
      useAuth: true,
    );

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (res != null && res['session_id'] != null) {
      setState(() => sessions.add(res));
      TtsService.speak("Session $title created successfully");
      
      _titleController.clear();
      
      // Ask if they want to start the session now
      if (mounted) {
        final startNow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Session Created'),
            content: Text('Do you want to start "$title" now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start Now'),
              ),
            ],
          ),
        );

        if (startNow == true) {
          _openSession(res['session_id']);
        }
      }
    } else {
      TtsService.speak("Failed to create session");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create session")),
        );
      }
    }
  }

  void _openSession(int sessionId) {
    if (currentUserId == null || currentUserName == null) {
      TtsService.speak("User not logged in");
      return;
    }

    TtsService.speak("Opening session");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          sessionId: sessionId,
          userId: currentUserId!,
          userName: currentUserName!,
          isTeacher: true,
        ),
      ),
    ).then((_) {
      // Refresh sessions when returning
      _loadSessions();
    });
  }

  Future<void> _deleteSession(int sessionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ApiService.delete('/sessions/$sessionId');
    
    if (success) {
      setState(() {
        sessions.removeWhere((s) => s['session_id'] == sessionId);
      });
      TtsService.speak("Session deleted");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session deleted successfully")),
        );
      }
    } else {
      TtsService.speak("Failed to delete session");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete session")),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
        title: const Text("Teacher Dashboard"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (currentUserName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      currentUserName!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
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
      body: SafeArea(
        child: SingleChildScrollView(  // ← ADD THIS
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Card(
                  elevation: 4,
                  color: Colors.indigo.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome, ${currentUserName ?? 'Teacher'}!",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Manage your sessions and connect with students",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Create Session Button
                ElevatedButton.icon(
                  onPressed: createSession,
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  label: const Text(
                    "Create New Session",
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Sessions Header
                Row(
                  children: [
                    const Text(
                      "Your Sessions",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (sessions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sessions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Sessions List - NO EXPANDED, just list items
                if (sessions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No active sessions yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Create your first session to get started",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...sessions.map((s) {
                    final sessionId = s['session_id'] ?? 0;
                    final title = s['title'] ?? 'Untitled Session';
                    final participantCount = s['participant_count'] ?? 0;
                    final createdAt = s['created_at'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _openSession(sessionId),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Session Icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    '$sessionId',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Session Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$participantCount participant${participantCount != 1 ? 's' : ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created: $createdAt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Action Buttons
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _openSession(sessionId),
                                    icon: const Icon(Icons.login, size: 18),
                                    label: const Text("Open"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  IconButton(
                                    onPressed: () => _deleteSession(sessionId, title),
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    tooltip: "Delete Session",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}