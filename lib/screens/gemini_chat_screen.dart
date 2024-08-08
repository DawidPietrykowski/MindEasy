import 'package:flutter/material.dart';
import 'package:gemini_app/bloc/gemini_state.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gemini_app/eeg/eeg_service.dart';
import 'package:get_it/get_it.dart';

class GeminiScreen extends StatelessWidget {
  const GeminiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => GeminiCubit()),
      ],
      child: const GeminiChat(),
    );
  }
}

class GeminiChat extends StatefulWidget {
  const GeminiChat({super.key});

  @override
  GeminiChatState createState() => GeminiChatState();
}

class GeminiChatState extends State<GeminiChat> {
  final _textController = TextEditingController();
  bool _quizMode = false; // Add this line
  final EegService _eegService = GetIt.instance<EegService>();

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  void _toggleQuizMode() {
    setState(() {
      _quizMode = !_quizMode;
    });
  }

  void _checkAnswer(int answer) {
    context.read<GeminiCubit>().checkAnswer(answer);
  }

  @override
  void dispose() {
    _eegService.stopPolling();
    super.dispose();
  }

  void _startConversation() async {
    context.read<GeminiCubit>().startLesson();
  }

  void _sendMessage() async {
    context.read<GeminiCubit>().sendMessage(_textController.text);
    _textController.clear();
  }

  void _toggleEegState() {
    setState(() {
      _eegService.toggleState();
    });
  }

  void _resetConversation() {
    context.read<GeminiCubit>().resetConversation();
    _startConversation();
  }

  void _enterQuizMode() {
    context.read<GeminiCubit>().enterQuizMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: BlocBuilder<GeminiCubit, GeminiState>(
          builder: (context, state) {
            return Text(state.isQuizMode ? 'Quiz Mode' : 'Gemini Pro Chat');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Mind Wandering: ${_eegService.state.mindWandering.toStringAsFixed(2)}'),
                    Text(
                        'Focus: ${_eegService.state.focus.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<GeminiCubit, GeminiState>(
                builder: (context, state) {
                  if (state.status == GeminiStatus.loading) {
                    return buildChatList(state, loading: true);
                  } else if (state.status == GeminiStatus.error) {
                    return Text('Error: ${state.error}');
                  } else {
                    return buildChatList(state);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            BlocBuilder<GeminiCubit, GeminiState>(
              builder: (context, state) {
                return state.isQuizMode
                    ? Container()
                    : TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Enter your message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                //     BlocBuilder<GeminiCubit, GeminiState>(
                //       builder: (context, state) {
                //         return state.isQuizMode
                //             ? Container()
                //             : Expanded(
                //                 child: ElevatedButton(
                //                   onPressed: _sendMessage,
                //                   child: const Text('Send'),
                //                 ),
                //               );
                //       },
                //     ),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send),
                      SizedBox(width: 3),
                      Text('Send'),
                    ],
                  ),
                ),

                ElevatedButton(
                  onPressed: _resetConversation,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 3),
                      Text('Reset'),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _toggleEegState,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.toggle_on),
                      SizedBox(width: 3),
                      Text('Toggle State'),
                    ],
                  ),
                ),
                // ElevatedButton(
                //   onPressed: _enterQuizMode,
                //   child: const Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Icon(Icons.quiz),
                //       SizedBox(width: 8),
                //       Text('Start Quiz'),
                //     ],
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ListView buildChatList(GeminiState state, {bool loading = false}) {
    return ListView.builder(
      itemCount: state.messages.length + (loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length && loading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BouncingDots(),
              ),
            ),
          );
        }

        if (state.messages[index].type == MessageType.lessonScript || 
        state.messages[index].source == MessageSource.app) {
          // skip
          return Container();
        }

        final message = state.messages[index];
        // String text = message.parts.whereType<TextPart>().map((part) => part.text).join();
        String text = message.text;

        if (message.type == MessageType.quizQuestion) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(data: text),
                  ...message.quizOptions!.asMap().entries.map((entry) {
                    return ElevatedButton(
                      onPressed: () => {_checkAnswer(entry.key)},
                      child: Text(entry.value),
                    );
                  }),
                ],
              ),
            ),
          );
        } else if (message.type == MessageType.quizAnswer) {
          bool correct = message.text == message.quizOptions![message.correctAnswer!];
          var text = Text(
            correct
                ? "Correct!"
                : "Incorrect. The correct answer was: ${message.quizOptions![message.correctAnswer!]}",
            style: TextStyle(
              color: correct ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          );

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text],
              ),
            ),
          );
        } else {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: message.source == MessageSource.agent
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [MarkdownBody(data: text)],
              ),
            ),
          );
        }
      },
    );
  }
}

class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key});

  @override
  BouncingDotsState createState() => BouncingDotsState();
}

class BouncingDotsState extends State<BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    _animations = _controllers
        .map((controller) => Tween<double>(begin: 0, end: -10).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            ))
        .toList();

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              padding: const EdgeInsets.all(2.5),
              child: Transform.translate(
                offset: Offset(0, _animations[index].value),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
