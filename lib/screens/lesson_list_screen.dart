import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:gemini_app/lesson.dart';
import 'package:gemini_app/main.dart';
import 'package:gemini_app/screens/gemini_chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
      body: AnimationLimiter(
        child: ListView.separated(
          itemCount: lessons.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Card(
                    elevation: 4,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text(
                        lesson.title,
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      subtitle: Text(
                        lesson.content,
                        style: GoogleFonts.roboto(fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          createSmoothRoute(
                            GeminiScreen(lessonId: lesson.id.toString()),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
