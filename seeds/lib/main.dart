import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _speak("To login as student press 1. To login as teacher press 2.");
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentClassesPage(userType: "Teacher")),
        );
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassesPage(userType: "Teacher")),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF93ACD4),
        body: Center(
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
// ---------------- Student Classes Page -----------------
class StudentClassesPage extends StatefulWidget {
  final String userType;
  const StudentClassesPage({super.key, required this.userType});
  @override
  State<StudentClassesPage> createState() => _StudentClassesPageState();
}
class _StudentClassesPageState extends State<StudentClassesPage> {
  final FlutterTts flutterTts = FlutterTts();
  final List<String> classes = ["Biology Class", "Math Class", "Physics Class"];
  int currentIndex = 0;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _speak(
        "You can either pick up a call or start self learning. To start self learning, select a class and press 2."
      );
    });
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (currentIndex < classes.length - 1) currentIndex++;
        });
        _speak(classes[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (currentIndex > 0) currentIndex--;
        });
        _speak(classes[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelfLearningPage(className: classes[currentIndex]),
          ),
        );
      }
      // You can add more keys if you want.
    }
  }
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF93ACD4),
        appBar: AppBar(
          backgroundColor: const Color(0xFF93ACD4),
          elevation: 0,
          title: Text(
            "My Classes - ${widget.userType}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Container(
            color: Colors.transparent,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        currentIndex == index ? Colors.yellow[200] : Colors.white,
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    classes[index],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
// ---------------- Self Learning Page -----------------
class SelfLearningPage extends StatefulWidget {
  final String className;
  const SelfLearningPage({super.key, required this.className});
  @override
  State<SelfLearningPage> createState() => _SelfLearningPageState();
}
class _SelfLearningPageState extends State<SelfLearningPage> {
  final FlutterTts flutterTts = FlutterTts();
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      await _speak(
          "Press 1 to listen to past recordings, press 2 to start a quiz.");
    });
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        // Add logic to play past recordings or navigate
        // For now, just a placeholder
        _speak("Playing past recordings.");
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        // Add logic to start quiz or navigate
        // For now, just a placeholder
        _speak("Starting the quiz.");
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF93ACD4),
        appBar: AppBar(
          backgroundColor: const Color(0xFF93ACD4),
          elevation: 0,
          title: Text("Self Learning - ${widget.className}"),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Press 1 to listen to past recordings.",
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  "Press 2 to start a quiz.",
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ---------------- Classes Page -----------------
class ClassesPage extends StatefulWidget {
  final String userType;
  const ClassesPage({super.key, required this.userType});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}
class _ClassesPageState extends State<ClassesPage> {
  final FlutterTts flutterTts = FlutterTts();
  final List<String> classes = ["Biology Class", "Math Class", "Physics Class"];
  int currentIndex = 0;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _speak(
        "Go to the class and press 1 for list of students and press 2 for starting a call.",
      );
    });
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      print("Key pressed: ${event.logicalKey}"); // Debug log
   
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (currentIndex < classes.length - 1) currentIndex++;
        });
        _speak(classes[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (currentIndex > 0) currentIndex--;
        });
        _speak(classes[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        print("Navigating to Students List"); // Debug log
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentsListPage(className: classes[currentIndex]),
          ),
        );
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        print("Navigating to Call Page"); // Debug log
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallPage(className: classes[currentIndex]),
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF93ACD4),
        appBar: AppBar(
          backgroundColor: const Color(0xFF93ACD4),
          elevation: 0,
          title: Text(
            "My Classes - ${widget.userType}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Container(
            color: Colors.transparent,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        currentIndex == index ? Colors.yellow[200] : Colors.white,
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
        ),
      ),
    );
  }
}
// ---------------- Students List Page -----------------
class StudentsListPage extends StatefulWidget {
  final String className;
  StudentsListPage({super.key, required this.className});
  final List<String> students = ["Ria", "Pria", "Akhil", "Kaushik"];
  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}
class _StudentsListPageState extends State<StudentsListPage> {
  final FlutterTts flutterTts = FlutterTts();
  int currentIndex = 0;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
  _focusNode.requestFocus();
  await _speak("Press 1 to add students. To remove students, go select the student and press 2.");
  await Future.delayed(const Duration(seconds: 8));
  await _speak(widget.students[currentIndex]);
});
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  void _handleKeyEvent(KeyEvent event) async {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (currentIndex < widget.students.length - 1) currentIndex++;
        });
        _speak(widget.students[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (currentIndex > 0) currentIndex--;
        });
        _speak(widget.students[currentIndex]);
      } else if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                 event.logicalKey == LogicalKeyboardKey.numpad1) {
        // Add student logic -- Use a dialog or route as needed
     
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                 event.logicalKey == LogicalKeyboardKey.numpad2) {
        // Remove currently selected student
        String removed = widget.students[currentIndex];
        setState(() {
          widget.students.removeAt(currentIndex);
          if (currentIndex >= widget.students.length) currentIndex = 0;
        });
        _speak("$removed has been removed.");
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF93ACD4),
        appBar: AppBar(
  backgroundColor: const Color(0xFF93ACD4),
  elevation: 0,
  title: Text(widget.className),
  actions: [
    IconButton(
      icon: const Icon(Icons.add, color: Colors.red),
      onPressed: () {
        // Add student logic here (e.g., open dialog)
      },
    ),
  ],
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.students.asMap().entries.map((entry) {
              int index = entry.key;
              String s = entry.value;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentIndex == index
                      ? Colors.yellow[200]
                      : const Color(0xFFFDF0F7),
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s, style: const TextStyle(fontSize: 18)),
                    const Text("-", style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
// ---------------- Call Page -----------------
class CallPage extends StatelessWidget {
  final String className;
  CallPage({super.key, required this.className});
  final List<String> students = [
    "Venkat Sir",
    "Ria",
    "Pria",
    "Kaushik",
    "Akhil"
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF93ACD4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF93ACD4),
        elevation: 0,
        title: Text(className),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "$className\n${students.length} Students in call",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Venkat Sir", style: TextStyle(fontSize: 18)),
                Icon(Icons.mic, color: Colors.red),
              ],
            ),
          ),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: students
                .where((s) => s != "Venkat Sir")
                .map((s) => Container(
                      width: 120,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s, style: const TextStyle(fontSize: 18)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 30),
          FloatingActionButton(
            onPressed: () {},
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.mic, size: 32),
          ),
        ],
      ),
    );
  }
}
