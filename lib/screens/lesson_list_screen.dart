import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gemini_app/lesson.dart';
import 'package:gemini_app/main.dart';
import 'package:gemini_app/screens/gemini_chat_screen.dart';

class LessonListScreen extends StatefulWidget {
  @override
  _LessonListScreenState createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  List<Lesson> lessons = [];

  @override
  void initState() {
    super.initState();
    loadLessons();
  }

  Future<void> loadLessons() async {
    final String response =
        await rootBundle.loadString('assets/lessons/lessons.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      lessons = data.map((json) => Lesson.fromJson(json)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Lessons'),
      ),
      body: ListView.separated(
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          return ListTile(
            title: Text(lesson.title),
            subtitle: Text(lesson.content),
            onTap: () {
              Navigator.push(
                context,
                createSmoothRoute(
                  GeminiScreen(lessonId: lesson.id.toString()),
                ),
              );
            },
          );
        },
        separatorBuilder: (context, index) {
          return Divider(); // or any other widget you want to use as a separator
        },
      ),
    );
  }
}
