class Lesson {
  final String id;
  final String title;
  final String content;

  Lesson({required this.id, required this.title, required this.content});

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      title: json['title'],
      content: json['content'],
    );
  }
}
