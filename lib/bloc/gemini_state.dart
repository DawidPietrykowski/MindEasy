import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:gemini_app/config.dart';
import 'package:gemini_app/bloc/eeg_state.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const String systemPrmpt =
    """You are an AI tutor helping students understand topics with help of biometric data. You will be supplied with a json containing data extracted from an EEG device, use that data to modify your approach and help the student learn more effectively.
At the start you will be provided a script with a lesson to cover.
Keep the analysis and responses short.
Use language: POLISH

After completing the theoretical part there's a quiz, you can start it yourself at the appropriate time or react to users' request by including <QUIZ_START_TOKEN> at the start of your response

Write the response in markdown and split it into two parts (include the tokens):
optional: <QUIZ_START_TOKEN>
<ANALYSIS_START_TOKEN>
here describe what is the state of the student and how to best approach them
<LESSON_START_TOKEN>
here continue with the lesson, respond to answers, etc
""";

enum GeminiStatus { initial, loading, success, error }

// enum MessageType { text, image, audio, video }

enum MessageSource { user, agent }

class QuizMessage {
  final String content;
  final List<String> options;
  final int correctAnswer;
  int? userAnswer;

  QuizMessage({
    required this.content,
    required this.options,
    required this.correctAnswer,
    this.userAnswer,
  });
}

// class Message {
//   final String text;
//   final MessageType type;
//   final MessageSource source;

//   Message({
//     required this.text,
//     required this.type,
//     required this.source,
//   });
// }

enum MessageType { text, lessonScript, quizQuestion, quizAnswer }

class Message {
  final String text;
  final MessageType type;
  final MessageSource source;
  final List<String>? quizOptions; // Add this for ABCD options
  final int? correctAnswer; // Add this for the correct answer index

  Message({
    required this.text,
    required this.type,
    required this.source,
    this.quizOptions,
    this.correctAnswer,
  });

  static Message fromGeminiContent(Content content) {
    if (content.parts.isNotEmpty) {
      final part = content.parts.first;
      if (part is TextPart) {
        return Message(
          text: part.text,
          type: MessageType.text,
          source: content.role == 'model'
              ? MessageSource.agent
              : MessageSource.user,
        );
      }
    }
    throw UnsupportedError('Unsupported content type');
  }

  Content toGeminiContent() {
    if (source == MessageSource.user || type == MessageType.lessonScript) {
      return Content.text(text);
    } else {
      return Content.model([TextPart(text)]);
    }
  }
}

class QuizQuestion {
  String question;
  List<String> options;
  int correctAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}

class GeminiState {
  GeminiStatus status;
  String error;
  List<Message> messages;
  List<QuizQuestion>? quizQuestions;
  bool isQuizMode;
  int currentQuizIndex;
  GenerativeModel? model;

  GeminiState(
      {required this.status,
      this.error = '',
      this.messages = const [],
      this.quizQuestions,
      this.isQuizMode = false,
      this.currentQuizIndex = -1,
      this.model});

  GeminiState copyWith({
    GeminiStatus? status,
    String? error,
    List<Message>? messages,
    List<QuizQuestion>? quizQuestions,
    bool? isQuizMode,
    int? currentQuizIndex,
    GenerativeModel? model,
  }) {
    return GeminiState(
      status: status ?? this.status,
      error: error ?? this.error,
      messages: messages ?? this.messages,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      isQuizMode: isQuizMode ?? this.isQuizMode,
      currentQuizIndex: currentQuizIndex ?? this.currentQuizIndex,
      model: model ?? this.model,
    );
  }

  static GeminiState get initialState => GeminiState(
        status: GeminiStatus.initial,
        // messages: [Message(text: "Hello, I'm Gemini Pro. How can I help you?", type: MessageType.text, source: MessageSource.agent)],
        messages: [
          // Message.fromGeminiContent(Content.model(
          //     [TextPart("Hello, I'm Gemini Pro. How can I help you?")]))
        ],
        error: '',
      );
}

class GeminiCubit extends Cubit<GeminiState> {
  GeminiCubit() : super(GeminiState.initialState);

  void startLesson(EegState eegState) async {
    final quizQuestions = await loadQuizQuestions();
    final String rjp = await rootBundle.loadString('assets/lessons/rjp.md');
    final String prompt =
        "Jesteś nauczycielem/chatbotem prowadzącym zajęcia z jednym uczniem. Uczeń ma możliwość zadawania pytań w trakcie, natomiast jesteś odpowiedzialny za prowadzenie lekcji i przedstawienie tematu. Zacznij prowadzić lekcje dla jednego ucznia na podstawie poniszego skryptu:\n$rjp";

    final safetySettings = [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ];

    final model = GenerativeModel(
        model: 'gemini-1.5-pro-latest',
        apiKey: geminiApiKey,
        safetySettings: safetySettings,
        systemInstruction: Content.system(systemPrmpt));

    Message lessonScriptMessage = Message(
      text: prompt,
      type: MessageType.lessonScript,
      source: MessageSource.agent,
    );

    GeminiState initialState = GeminiState(
        status: GeminiStatus.loading,
        error: '',
        messages: [lessonScriptMessage],
        quizQuestions: quizQuestions,
        isQuizMode: false,
        model: model);
    emit(initialState);

    try {
      final chat = state.model!.startChat(history: [Content.text(prompt)]);
      final stream = chat.sendMessageStream(Content.text(
          "EEG DATA:\n${eegState.getJsonString()}\nPytanie:\n$prompt"));

      String responseText = '';

      await for (final chunk in stream) {
        responseText += chunk.text ?? '';
        emit(initialState.copyWith(
            status: GeminiStatus.success,
            messages: [
              lessonScriptMessage,
              Message(
                  source: MessageSource.agent,
                  text: responseText,
                  type: MessageType.text)
            ],
            model: model));
      }
    } catch (e) {
      emit(GeminiState(
        status: GeminiStatus.error,
        messages: state.messages,
        error: e.toString(),
      ));
    }

    // enterQuizMode();

    // sendMessage(prompt, eegState);
  }

  void sendMessage(String prompt, EegState eegState) async {
    List<Message> messagesWithoutPrompt = state.messages;
    var messagesWithPrompt = state.messages +
        [
          Message(
              text: prompt, type: MessageType.text, source: MessageSource.user)
        ];

    emit(state.copyWith(
      status: GeminiStatus.loading,
      messages: messagesWithPrompt,
    ));

    try {
      final chat = state.model!.startChat(
          history: messagesWithoutPrompt
              .map((mess) => mess.toGeminiContent())
              .toList());
      final stream = chat.sendMessageStream(Content.text(
          "EEG DATA:\n${eegState.getJsonString()}\nWiadomość od ucznia:\n$prompt"));

      String responseText = '';

      await for (final chunk in stream) {
        responseText += chunk.text ?? '';
        emit(state.copyWith(
            status: GeminiStatus.success,
            messages: messagesWithPrompt +
                [
                  Message(
                      source: MessageSource.agent,
                      text: responseText,
                      type: MessageType.text)
                ]));
      }

      if (responseText.contains("<QUIZ_START_TOKEN>")) {
        enterQuizMode();
      }
    } catch (e) {
      emit(GeminiState(
        status: GeminiStatus.error,
        messages: messagesWithPrompt,
        error: e.toString(),
      ));
    }
  }

  void passAnswerToGemini(int answer) async {
    final quizQuestion = state.quizQuestions![state.currentQuizIndex];

    final answerMessage = Message(
      text: quizQuestion.options[answer],
      type: MessageType.quizAnswer,
      source: MessageSource.user,
      quizOptions: quizQuestion.options,
      correctAnswer: quizQuestion.correctAnswer,
    );

    final List<Message> updatedMessages = [
      ...state.messages,
      answerMessage,
    ];

    emit(state.copyWith(messages: updatedMessages));

    askNextQuizQuestion();
  }

  Future<List<QuizQuestion>> loadQuizQuestions() async {
    final String quizJson =
        await rootBundle.loadString('assets/lessons/rjp.json');
    final List<dynamic> quizData = json.decode(quizJson);

    return quizData
        .map((question) => QuizQuestion(
              question: question['question'],
              options: List<String>.from(question['options']),
              correctAnswer: question['correctAnswer'],
            ))
        .toList();
  }

  void enterQuizMode() async {
    if (state.isQuizMode) return; // Prevent re-entering quiz mode
    askNextQuizQuestion();
  }

  void askNextQuizQuestion() {
    var currentQuizIndex = state.currentQuizIndex + 1;
    final quizQuestion = state.quizQuestions![currentQuizIndex];

    final quizQuestionMessage = Message(
      text: quizQuestion.question,
      type: MessageType.quizQuestion,
      source: MessageSource.agent,
      quizOptions: quizQuestion.options,
      correctAnswer: quizQuestion.correctAnswer,
    );

    final List<Message> updatedMessages = [
      ...state.messages,
      quizQuestionMessage,
    ];

    emit(state.copyWith(
        messages: updatedMessages,
        isQuizMode: true,
        currentQuizIndex: currentQuizIndex));
  }

  void checkAnswer(int answerIndex) {
    passAnswerToGemini(answerIndex);
  }

  void resetConversation() {
    emit(GeminiState.initialState);
  }
}
