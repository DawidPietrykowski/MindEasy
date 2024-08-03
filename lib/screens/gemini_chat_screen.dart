import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gemini_app/bloc/eeg_state.dart';
import 'package:gemini_app/bloc/gemini_state.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GeminiScreen extends StatelessWidget {
  const GeminiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => GeminiCubit()),
        BlocProvider(create: (context) => EegCubit()),
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
    context.read<EegCubit>().stopPolling();
    super.dispose();
  }

  void _startConversation() async {
    context.read<GeminiCubit>().startLesson(context.read<EegCubit>().state);
  }

  void _sendMessage() async {
    context
        .read<GeminiCubit>()
        .sendMessage(_textController.text, context.read<EegCubit>().state);
    _textController.clear();
  }

  void _toggleEegState() {
    context.read<EegCubit>().toggleState();
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
          children: [
            BlocBuilder<EegCubit, EegState>(
              builder: (context, eegState) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Mind Wandering: ${eegState.mind_wandering.toStringAsFixed(2)}'),
                        Text('Focus: ${eegState.focus.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                );
              },
            ),
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
            BlocBuilder<GeminiCubit, GeminiState>(
              builder: (context, state) {
                return state.isQuizMode
                    ? Container() // Hide text input in quiz mode
                    : TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your message',
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      );
              },
            ),
            Row(
              children: [
                BlocBuilder<GeminiCubit, GeminiState>(
                  builder: (context, state) {
                    return state.isQuizMode
                        ? Container()
                        : Expanded(
                            child: ElevatedButton(
                              onPressed: _sendMessage,
                              child: const Text('Send'),
                            ),
                          );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resetConversation,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _toggleEegState,
                  child: const Text('Toggle State'),
                ),
                const SizedBox(width: 8),
                BlocBuilder<GeminiCubit, GeminiState>(
                  builder: (context, state) {
                    return state.isQuizMode
                        ? Container()
                        : ElevatedButton(
                            onPressed: _enterQuizMode,
                            child: const Text('Start Quiz'),
                          );
                  },
                ),
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

        if (state.messages[index].type == MessageType.lessonScript) {
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
          bool correct = message.text == message.correctAnswer;
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
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
