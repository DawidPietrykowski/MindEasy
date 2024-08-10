import 'package:flutter/material.dart';
import 'package:gemini_app/eeg/eeg_service.dart';
import 'package:gemini_app/screens/eeg_calibration_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GetIt.I.registerSingleton<EegService>(EegService());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindEasy',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        textTheme: GoogleFonts.openSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const MindWanderScreen(),
    );
  }
}

Route createSmoothRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: Curves.easeInOut));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration:
        Duration(milliseconds: 300), // Adjust the duration to your preference
    reverseTransitionDuration:
        Duration(milliseconds: 300), // Adjust for reverse transition too
  );
}
