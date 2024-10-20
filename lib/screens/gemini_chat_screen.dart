import 'package:flutter/material.dart';
import 'package:gemini_app/bloc/gemini_state.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gemini_app/config.dart';
import 'package:gemini_app/eeg/eeg_service.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

class GeminiScreen extends StatelessWidget {
  const GeminiScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => GeminiCubit()),
      ],
      child: GeminiChat(
        lessonId: lessonId,
      ),
    );
  }
}

class GeminiChat extends StatefulWidget {
  const GeminiChat({super.key, required this.lessonId});

  final String lessonId;

  @override
  GeminiChatState createState() => GeminiChatState();
}

class GeminiChatState extends State<GeminiChat> {
  final _textController = TextEditingController();
  bool _quizMode = false;
  final EegService _eegService = GetIt.instance<EegService>();
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose(); // Add this line
    super.dispose();
  }

  void _startConversation() async {
    context.read<GeminiCubit>().startLesson(widget.lessonId);
  }

  void _sendMessage() async {
    context.read<GeminiCubit>().sendMessage(_textController.text);
    _textController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
            isDebug
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Mind Wandering: ${(_eegService.state.mindWandering ?? 0).toStringAsFixed(2)}',
                              style: GoogleFonts.roboto(
                                textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )),
                          Text(
                              'Focus: ${(_eegService.state.focus ?? 0).toStringAsFixed(2)}',
                              style: GoogleFonts.roboto(
                                textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )),
                        ],
                      ),
                    ),
                  )
                : Container(),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<GeminiCubit, GeminiState>(
                builder: (context, state) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

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
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter your message',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          // fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 14.0),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
                if (isDebug)
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
                  )
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
      controller: _scrollController,
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
            state.messages[index].source == MessageSource.app || state.messages[index].text == "") {
          // skip
          return Container();
        }

        final message = state.messages[index];
        String text = message.text;
        if (text.contains("User message:\n")){
          text = text.substring(text.indexOf("User message:\n") + 14);
        }

        text = text.replaceAll(END_LESSON_TOKEN, "");
        text = text.replaceAll(ANALYSIS_START_TOKEN, "");
        text = text.replaceAll(LESSON_START_TOKEN, "");

        if (message.type == MessageType.quizQuestion) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w300)),
                      )),
                  const SizedBox(height: 16),
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
          bool correct =
              message.text == message.quizOptions![message.correctAnswer!];
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
                children: [
                  MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w300)),
                      ))
                ],
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
                    color: Colors.white,
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
