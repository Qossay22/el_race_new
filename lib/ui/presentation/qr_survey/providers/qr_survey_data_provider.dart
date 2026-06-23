import 'package:flutter/foundation.dart';

/// Provider for managing QR Survey dynamic data
/// Stores the content type (survey/documents/media) and data
class QrSurveyDataProvider with ChangeNotifier {
  Map<String, dynamic>? _contentData;
  bool _isFromQrCode = false; // Track if accessed via QR code

  Map<String, dynamic>? get contentData => _contentData;

  String? get contentType => _contentData?['type'];

  List<dynamic>? get data => _contentData?['data'];

  int? get surveyId => _contentData?['survey_id'];

  String? get title => _contentData?['title'];

  bool get hasContent => _contentData != null;

  bool get isSurvey => contentType == 'survey';

  bool get isDocuments => contentType == 'documents';

  bool get isMedia => contentType == 'media';

  /// Check if content was loaded from QR code
  bool get isFromQrCode => _isFromQrCode;

  void setContentData(Map<String, dynamic>? data, {bool fromQrCode = false}) {
    _contentData = data;
    _isFromQrCode = fromQrCode;
    notifyListeners();
  }

  void clearData() {
    _contentData = null;
    _isFromQrCode = false;
    notifyListeners();
  }
}
