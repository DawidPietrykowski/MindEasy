import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:gemini_app/api_key.dart';
import 'package:gemini_app/eeg/eeg_service.dart';
import 'package:get_it/get_it.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const String systemPrmpt =
    """You are an AI tutor helping students understand topics with help of biometric data. You will be supplied with a json containing data extracted from an EEG device, use that data to modify your approach and help the student learn more effectively.
At the start you will be provided a script with a lesson to cover.
Keep the analysis short but the lesson can be as long as needed.
Student is 20 years old. You can only interact using text, no videos, images, or audio.
Make the lesson more in the style of a lecture, with you explaining the topic and the student asking questions.

After completing the theoretical part there's a quiz, you can start it yourself at the appropriate time or react to users' request by including <QUIZ_START_TOKEN> at the start of your response

Write the response in markdown and split it into two parts (include the tokens):
optional: <QUIZ_START_TOKEN> (makes the app transition to quiz mode, do not write the question yourself, use it ONLY when you want to start the quiz)
<ANALYSIS_START_TOKEN>
here describe what is the state of the student and how to best approach them
<LESSON_START_TOKEN>
here continue with the lesson, respond to answers, etc
""";

const String LESSON_START_TOKEN = "<LESSON_START_TOKEN>";
const String ANALYSIS_START_TOKEN = "<ANALYSIS_START_TOKEN>";
const String QUIZ_START_TOKEN = "<QUIZ_START_TOKEN>";

enum GeminiStatus { initial, loading, success, error }

// enum MessageType { text, image, audio, video }

enum MessageSource { user, agent, app }

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
    switch (type) {
      case MessageType.text:
        if (source == MessageSource.user) {
          return Content.text(text);
        } else {
          return Content.model([TextPart(text)]);
        }
      case MessageType.lessonScript:
        return Content.text(text);
      case MessageType.quizQuestion:
        String question = text;
        List<String> options =
            quizOptions!.map((option) => option.trim()).toList();
        String answer = options[correctAnswer!];
        String formattedQuestion =
            "$question\n\nOptions:\n${options.map((option) => "- $option").join('\n')}\n\nCorrect Answer: $answer";
        return Content.model([TextPart(formattedQuestion)]);
      case MessageType.quizAnswer:
        String expectedAnswer = quizOptions![correctAnswer!];
        bool userCorrect = expectedAnswer == text;
        String result = userCorrect
            ? "User answered correctly with: $text"
            : "User answered incorrectly with: $text instead of $expectedAnswer";
        return Content.text(result);
      default:
        throw UnsupportedError('Unsupported message type');
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
  String? lessonId;

  GeminiState(
      {required this.status,
      this.error = '',
      this.messages = const [],
      this.quizQuestions,
      this.isQuizMode = false,
      this.currentQuizIndex = -1,
      this.model,
      this.lessonId});

  GeminiState copyWith({
    GeminiStatus? status,
    String? error,
    List<Message>? messages,
    List<QuizQuestion>? quizQuestions,
    bool? isQuizMode,
    int? currentQuizIndex,
    GenerativeModel? model,
    String? lessonId,
  }) {
    return GeminiState(
      status: status ?? this.status,
      error: error ?? this.error,
      messages: messages ?? this.messages,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      isQuizMode: isQuizMode ?? this.isQuizMode,
      currentQuizIndex: currentQuizIndex ?? this.currentQuizIndex,
      model: model ?? this.model,
      lessonId: lessonId ?? this.lessonId,
    );
  }

  static GeminiState get initialState => GeminiState(
        status: GeminiStatus.initial,
        messages: [],
        error: '',
      );
}

class GeminiCubit extends Cubit<GeminiState> {
  GeminiCubit() : super(GeminiState.initialState);

  void startLesson(String lessonId) async {
    final quizQuestions = await loadQuizQuestions(lessonId);
    final String lessonScript =
        await rootBundle.loadString('assets/lessons/$lessonId.md');
    // final String prompt =
    // "Jesteś nauczycielem/chatbotem prowadzącym zajęcia z jednym uczniem. Uczeń ma możliwość zadawania pytań w trakcie, natomiast jesteś odpowiedzialny za prowadzenie lekcji i przedstawienie tematu. Zacznij prowadzić lekcje dla jednego ucznia na podstawie poniszego skryptu:\n$rjp";
    final String prompt =
        "You are a lecturer teaching a class with one student. The student has the ability to ask questions during the lesson, while you are responsible for lecturing and presenting the topic. Start conducting the lecture for one student based on the script below:\n$lessonScript";

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
        model: model,
        lessonId: lessonId);
    emit(initialState);

    sendMessage("");
  }

  void sendMessage(String prompt) async {
    List<Message> messagesWithoutPrompt = state.messages;
    List<Message> messagesWithPrompt;
    if (prompt == "") {
      messagesWithPrompt = state.messages;
    } else {
      messagesWithPrompt = state.messages +
          [
            Message(
                text: prompt,
                type: MessageType.text,
                source: MessageSource.user)
          ];
    }

    emit(state.copyWith(
      status: GeminiStatus.loading,
      messages: messagesWithPrompt,
    ));

    try {
      final chatHistory =
          messagesWithoutPrompt.map((mess) => mess.toGeminiContent()).toList();
      final chat = state.model!.startChat(history: chatHistory);
      final stream = chat.sendMessageStream(Content.text(
          "EEG DATA:\n${GetIt.instance<EegService>().state.getJsonString()}\nUser message:\n$prompt"));

      String responseText = '';

      bool isAnalysisDone = false;
      String analysisData = "";

      await for (final chunk in stream) {
        responseText += chunk.text ?? '';
        if (responseText.contains(LESSON_START_TOKEN)) {
          isAnalysisDone = true;
          var startIndex = responseText.indexOf(LESSON_START_TOKEN) +
              LESSON_START_TOKEN.length;
          analysisData = responseText.substring(0, startIndex);
          print("ANALYSIS DATA: $analysisData");
          responseText =
              responseText.substring(startIndex, responseText.length);
        }
        if (isAnalysisDone) {
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
      }

      if (responseText.contains(QUIZ_START_TOKEN) ||
          analysisData.contains(QUIZ_START_TOKEN)) {
        emit(state.copyWith(
            status: GeminiStatus.success, messages: messagesWithPrompt));
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

  Future<List<QuizQuestion>> loadQuizQuestions(String lessonId) async {
    final String quizJson =
        await rootBundle.loadString('assets/lessons/$lessonId.json');
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

    if (currentQuizIndex >= state.quizQuestions!.length ||
        currentQuizIndex >= 2) {
      // if (currentQuizIndex >= 2) {
      List<Message> messagesWithPrompt = state.messages +
          [
            Message(
                text: "Quiz is over. Write a summary of user's performance.",
                type: MessageType.text,
                source: MessageSource.app)
          ];

      // Quiz is over
      emit(state.copyWith(
          isQuizMode: false,
          currentQuizIndex: 0,
          messages: messagesWithPrompt));

      // Send a message to Gemini to end the quiz
      sendMessage("");

      return;
    }

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
