import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gemini_app/eeg/eeg_service.dart';
import 'package:gemini_app/main.dart';
import 'package:gemini_app/screens/lesson_list_screen.dart';
import 'package:get_it/get_it.dart';

class MindWanderScreen extends StatefulWidget {
  const MindWanderScreen({super.key});

  @override
  MindWanderScreenState createState() => MindWanderScreenState();
}

class MindWanderScreenState extends State<MindWanderScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late TextEditingController _serverUrlController;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _serverUrlController = TextEditingController();
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
                  // Add a text field with a button for connecting to a server in a dev version
                  _isConnected
                      ? Container()
                      : FormField(builder: (FormFieldState state) {
                          return Column(children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Server URL',
                                hintText: 'http://192.168.1.112:1234',
                              ),
                              controller: _serverUrlController,
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await EegService.fetchEegData(
                                      _serverUrlController.text);
                                  GetIt.I<EegService>().startPolling(_serverUrlController.text);
                                  setState(() {
                                    _isConnected = true;
                                  });
                                } catch (e) {
                                  print('Failed to connect to server: $e');
                                  // Show an error dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Connection Error',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        content: Text(e.toString(),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                            )),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              },
                              child: const Text('Connect'),
                            ),
                          ]);
                        }),
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
