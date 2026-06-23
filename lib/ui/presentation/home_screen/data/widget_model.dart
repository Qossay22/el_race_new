class WidgetModel {
  final String id;
  final String title;
  final String? iconPath;
  final String? backgroundPath;
  final bool isActive;

  const WidgetModel({
    required this.id,
    required this.title,
    this.iconPath,
    this.backgroundPath,
    this.isActive = false,
  });

  WidgetModel copyWith({
    String? id,
    String? title,
    String? iconPath,
    String? backgroundPath,
    bool? isActive,
  }) {
    return WidgetModel(
      id: id ?? this.id,
      title: title ?? this.title,
      iconPath: iconPath ?? this.iconPath,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconPath': iconPath,
      'backgroundPath': backgroundPath,
      'isActive': isActive,
    };
  }

  factory WidgetModel.fromJson(Map<String, dynamic> json) {
    return WidgetModel(
      id: json['id'],
      title: json['title'],
      iconPath: json['iconPath'],
      backgroundPath: json['backgroundPath'],
      isActive: json['isActive'] ?? false,
    );
  }
}

List<WidgetModel> getAvailableWidgets() {
  return [
    const WidgetModel(
      id: 'time_sheet',
      title: 'Time Sheet',
    ),
    const WidgetModel(
      id: 'petty_cash',
      title: 'Petty Cash',
      iconPath: 'assets/newapp/petty_cash.svg',
      backgroundPath: 'assets/png/pettycash_new_bg.png',
    ),
    const WidgetModel(
      id: 'lpo',
      title: 'LPO',
      iconPath: 'assets/png/lpo.png',
      backgroundPath: 'assets/png/notes_new_bg.png',
    ),
    const WidgetModel(
      id: 'documents',
      title: 'Documents',
      iconPath: 'assets/png/icons/doc_icon.png',
      backgroundPath: 'assets/png/gray_card.png',
    ),
    // My Notes widget hidden
    // const WidgetModel(
    //   id: 'my_notes',
    //   title: 'My Notes',
    //   iconPath: 'assets/png/notes_icon.png',
    //   backgroundPath: 'assets/png/blue_card.png',
    // ),
    const WidgetModel(
      id: 'todo_list',
      title: 'TO DO List',
      iconPath: 'assets/png/notes_icon.png',
      backgroundPath: 'assets/png/blue_card.png',
    ),
    const WidgetModel(
      id: 'projects',
      title: 'Projects',
      iconPath: 'assets/newapp/my_projects.svg',
      backgroundPath: 'assets/png/gray_card.png',
    ),
    const WidgetModel(
      id: 'my_request',
      title: 'My Request',
      iconPath: 'assets/png/my_request.png',
      backgroundPath: 'assets/png/gray_card.png',
    ),
    const WidgetModel(
      id: 'media',
      title: 'Media',
      iconPath: 'assets/png/icons/media_icon.png',
      backgroundPath: 'assets/png/gray_card.png',
    ),
    const WidgetModel(
      id: 'my_report',
      title: 'My Report',
      iconPath: 'assets/png/my_documents.png',
      backgroundPath: 'assets/png/notes_new_bg.png',
    ),
    const WidgetModel(
      id: 'qr_code',
      title: 'My QR Code',
      iconPath: 'assets/png/qr_code.png',
      backgroundPath: 'assets/png/gray_card.png',
    ),
    const WidgetModel(
      id: 'attendance',
      title: 'Attendance',
      iconPath: 'assets/png/date_attendance.png',
      backgroundPath: 'assets/png/attendace_new_bg.png',
    ),
    const WidgetModel(
      id: 'prayer',
      title: 'Prayer Times',
      iconPath: 'assets/png/prayer_icon.png',
      backgroundPath: 'assets/png/gray_card.png',
    ),
  ];
}
