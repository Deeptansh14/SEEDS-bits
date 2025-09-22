import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Text-to-Speech package

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speak("To login as student press 1. To login as teacher press 2.");
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentPage()),
        );
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF93ACD4),
      body: RawKeyboardListener(
        autofocus: true,
        focusNode: FocusNode(),
        onKey: _handleKey,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Login",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: false,
                          onChanged: null,
                        ),
                        const Text("Student"),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: false,
                          onChanged: null,
                        ),
                        const Text("Teacher"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Student Page -----------------
class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController studentIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speak("Type student ID");
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF93ACD4),
      appBar: AppBar(title: const Text("Student Login")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Type Student ID",
                style: TextStyle(fontSize: 24, color: Colors.black),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: studentIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Student ID",
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Teacher Page -----------------
class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController teacherIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speak("Type teacher ID");
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _goToClasses(String id) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ClassesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF93ACD4),
      appBar: AppBar(title: const Text("Teacher Login")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Type Teacher ID",
                style: TextStyle(fontSize: 24, color: Colors.black),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: teacherIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Teacher ID",
                  fillColor: Colors.white,
                  filled: true,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _goToClasses(value); // Directly navigate
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Classes Page -----------------
class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final FlutterTts flutterTts = FlutterTts();
  final List<String> classes = ["Biology Class", "Math Class", "Physics Class"];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentClass();
    });
  }

  Future<void> _speakCurrentClass() async {
    await flutterTts.speak(classes[currentIndex]);
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (currentIndex < classes.length - 1) currentIndex++;
        });
        _speakCurrentClass();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (currentIndex > 0) currentIndex--;
        });
        _speakCurrentClass();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF93ACD4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF93ACD4),
        elevation: 0,
        title: const Text(
          "My Classes",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: RawKeyboardListener(
        autofocus: true,
        focusNode: FocusNode(),
        onKey: _handleKey,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentIndex == index ? Colors.yellow[200] : Colors.white,
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    classes[index],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.call, color: Colors.black),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
