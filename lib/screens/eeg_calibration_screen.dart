import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gemini_app/main.dart';
import 'package:gemini_app/screens/lesson_list_screen.dart';

class MindWanderScreen extends StatefulWidget {
  const MindWanderScreen({super.key});

  @override
  MindWanderScreenState createState() => MindWanderScreenState();
}

class MindWanderScreenState extends State<MindWanderScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    // _startTimer();
  }

  void _startTimer() {
    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          // Perform any action when the timer reaches zero
          _skipCalibration();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _skipCalibration() {
    _timer?.cancel();
    Navigator.push(context, createSmoothRoute(LessonListScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EEG Calibration'),
      ),
      body: Stack(
        children: [
          // Background Animation
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                color: Colors.white,
                child: Opacity(
                  opacity: _animation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.withOpacity(0.5),
                          Colors.green.withOpacity(0.5),
                        ],
                        transform: GradientRotation(
                            _animation.value * 2 * 3.1415926535),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Main Content
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    """When you're ready, press the start button and start mind wandering by letting your thoughts drift to your favorite places or stories while you sit quietly""",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _timer == null
                      ? ElevatedButton(
                          onPressed: _startTimer,
                          child: const Text('Start'),
                        )
                      : Text(
                          'Time remaining: $_secondsRemaining seconds',
                          style: const TextStyle(fontSize: 18),
                        ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: ElevatedButton(
              onPressed: _skipCalibration,
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MindWanderScreen(),
  ));
}
