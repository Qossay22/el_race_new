class QrQuestionModel {
  final int id;
  final String title;
  final String description;
  final String type; // 'date', 'simple_choice', 'char_box'
  final bool isMandatory;
  final List<String>? suggestedAnswers; // for multiple choice questions
  String? selectedAnswer;
  String? textAnswer;
  DateTime? dateAnswer;

  QrQuestionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isMandatory,
    this.suggestedAnswers,
    this.selectedAnswer,
    this.textAnswer,
    this.dateAnswer,
  });

  factory QrQuestionModel.fromJson(Map<String, dynamic> json) {
    return QrQuestionModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'char_box',
      isMandatory: json['mandatory'] == true || json['is_mandatory'] == true,
      suggestedAnswers: json['suggested_answers'] != null
          ? List<String>.from(json['suggested_answers'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'mandatory': isMandatory,
      'suggested_answers': suggestedAnswers,
      'selected_answer': selectedAnswer,
      'text_answer': textAnswer,
      'date_answer': dateAnswer?.toIso8601String(),
    };
  }

  QrQuestionModel copyWith({
    int? id,
    String? title,
    String? description,
    String? type,
    bool? isMandatory,
    List<String>? suggestedAnswers,
    String? selectedAnswer,
    String? textAnswer,
    DateTime? dateAnswer,
  }) {
    return QrQuestionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      isMandatory: isMandatory ?? this.isMandatory,
      suggestedAnswers: suggestedAnswers ?? this.suggestedAnswers,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      textAnswer: textAnswer ?? this.textAnswer,
      dateAnswer: dateAnswer ?? this.dateAnswer,
    );
  }

  bool get isAnswered {
    if (!isMandatory) return true;

    switch (type) {
      case 'date':
        return dateAnswer != null;
      case 'simple_choice':
        return selectedAnswer != null && selectedAnswer!.isNotEmpty;
      case 'char_box':
        return textAnswer != null && textAnswer!.isNotEmpty;
      default:
        return false;
    }
  }
}
