import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:gemini_app/config.dart';
import 'package:gemini_app/bloc/eeg_state.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

enum GeminiStatus { initial, loading, success, error }
enum MessageType { text, image, audio, video }
enum MessageSource { user, agent }

class Message {
  final String text;
  final MessageType type;
  final MessageSource source;

  Message({
    required this.text,
    required this.type,
    required this.source,
  });
}

class GeminiState {
  GeminiStatus status;
  String error;
  List<Content> messages;

  GeminiState({
    required this.status,
    required this.error,
    this.messages = const [],
  });

  static GeminiState get initialState => GeminiState(
    status: GeminiStatus.initial,
    // messages: [Message(text: "Hello, I'm Gemini Pro. How can I help you?", type: MessageType.text, source: MessageSource.agent)],
    messages: [Content.model([TextPart("Hello, I'm Gemini Pro. How can I help you?")])],
    error: '',
  );
}

class GeminiCubit extends Cubit<GeminiState> {
  GeminiCubit() : super(GeminiState.initialState);

void sendMessage(String prompt, EegState eegState) async {
  var messagesWithoutPrompt = state.messages;
  var messagesWithPrompt = state.messages + [
    Content.text(prompt)
  ];

  emit(GeminiState(status: GeminiStatus.loading, messages: messagesWithPrompt, error: ''));
  final safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    // SafetySetting(HarmCategory.unspecified, HarmBlockThreshold.none),
  ];

  final String rjp = await rootBundle.loadString('assets/lessons/rjp.md');


  const String systemPrmpt = """You are an AI tutor helping students understand topics with help of biometric data. You will be supplied with a json containing data extracted from an EEG device, use that data to modify your approach and help the student learn more effectively.
  Use language: POLISH
Write the response in markdown and split it into two parts:
State analysis: describe what is the state of the student and how to best approach them
Tutor response: continue with the lesson, respond to answers, etc""";

  final model = GenerativeModel(
    model: 'gemini-1.5-pro-latest',
    apiKey: geminiApiKey,
    safetySettings: safetySettings,
    systemInstruction: Content.system(systemPrmpt)
  );

  try {
    final chat = model.startChat(history: messagesWithoutPrompt);
    final stream = chat.sendMessageStream(
    Content.text("EEG DATA:\n${eegState.getJsonString()}\nPytanie:\n$prompt")
    );

    String responseText = '';

    await for (final chunk in stream) {
      responseText += chunk.text ?? '';
      emit(GeminiState(
        status: GeminiStatus.success,
        messages: messagesWithPrompt + [Content.model([TextPart(responseText)])],
        error: '',
      ));
    }
  } catch (e) {
    emit(GeminiState(
      status: GeminiStatus.error,
      messages: messagesWithPrompt,
      error: e.toString(),
    ));
  }
}

  void resetConversation() {
    emit(GeminiState.initialState);
  }
}