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

@override
void initState() {
  super.initState();
  _startConversation();
  context.read<EegCubit>().startPolling();
}

@override
void dispose() {
  context.read<EegCubit>().stopPolling();
  super.dispose();
}

  void _startConversation() async {
    final String rjp = await rootBundle.loadString('assets/lessons/rjp.md');
    print(rjp);
    context.read<GeminiCubit>().sendMessage("Zacznij prowadzić lekcje na podstawie poniszego skryptu:\n" + rjp);
  }

  void _sendMessage() async {
    context.read<GeminiCubit>().sendMessage(_textController.text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Pro Chat'),
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
                      Text('Mind Wandering: ${eegState.mind_wandering.toStringAsFixed(2)}'),
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
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Enter your message',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
            ElevatedButton(
              onPressed: _sendMessage,
              child: const Text('Send'),
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BouncingDots(),
            ),
          ),
        );
      }

      final message = state.messages[index];

      String text = "";
      for (var part in message.parts) {
        if (part is TextPart) {
          text += part.text;
        }
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: message.role != 'user'
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              MarkdownBody(data: text),
            ],
          ),
        ),
      );
    },
  );
}
}


class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key});

  @override
  BouncingDotsState createState() => BouncingDotsState();
}

class BouncingDotsState extends State<BouncingDots> with TickerProviderStateMixin {
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
    _animations = _controllers.map((controller) =>
        Tween<double>(begin: 0, end: -10).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        )
    ).toList();

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
