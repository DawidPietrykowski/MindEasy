import 'dart:async';
import 'package:gemini_app/config.dart';
import 'package:http/http.dart' as http;

class EegState {
  final double mindWandering;
  final double focus;

  EegState({
    required this.mindWandering,
    required this.focus,
  });

  String getJsonString() {
    return '{"mind_wandering": $mindWandering, "focus": $focus}';
  }
}

class EegService {
  EegState state;

  EegService() : state = EegState(mindWandering: 0.1, focus: 0.9) {
    // Start the timer when the cubit is created
    if (!isSimulatedEEG) {
      startPolling();
    }
  }

  Timer? _timer;

  void startPolling() {
    // Poll every 1 second (adjust the duration as needed)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate getting new EEG data
      // In a real application, you would fetch this data from your EEG device or API
      // double newMindWandering = (DateTime.now().millisecondsSinceEpoch % 100) / 100;
      // double newFocus = 1 - newMindWandering;

      fetchEegData().then((data) {
        double newMindWandering = data[0];
        double newFocus = data[1];
        // Update the state with the new EEG data
        updateEegData(newMindWandering, newFocus);
      });

      // updateEegData(newMindWandering, newFocus);
    });
  }

  Future<List<double>> fetchEegData() async {
    if (isSimulatedEEG) {
      return [0.9, 0.1]; // Placeholder ret
    }

    final url = Uri.parse('http://192.168.83.153:1234');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Split the response body by newline and parse as floats
        List<String> values = response.body.trim().split('\n');
        if (values.length == 2) {
          return [
            double.parse(values[0]),
            double.parse(values[1]),
          ];
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load EEG data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching EEG data: $e');
    }
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void updateEegData(double mindWandering, double focus) {
    state = EegState(mindWandering: mindWandering, focus: focus);
    print('Mind Wandering: $mindWandering, Focus: $focus');
  }

  void toggleState() {
    // Toggle the state between mind_wandering and focus
    if (state.mindWandering > state.focus) {
      updateEegData(state.focus, state.mindWandering);
    } else {
      updateEegData(state.mindWandering, state.focus);
    }
  }
}
