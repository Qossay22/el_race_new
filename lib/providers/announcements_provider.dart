import 'package:flutter/foundation.dart';
import 'package:el_race/data/models/announcement_model.dart';
import 'package:el_race/data/services/announcements_api_service.dart';

/// Announcement state enumeration
enum AnnouncementState {
  idle,
  loading,
  loaded,
  empty,
  error,
}

/// Provider for managing announcements state
class AnnouncementsProvider extends ChangeNotifier {
  final AnnouncementsApiService _apiService;

  AnnouncementsProvider({AnnouncementsApiService? apiService})
      : _apiService = apiService ?? AnnouncementsApiService();

  // State
  AnnouncementState _state = AnnouncementState.idle;
  AnnouncementState get state => _state;

  // Data
  List<AnnouncementModel> _announcements = [];
  List<AnnouncementModel> get announcements => _announcements;

  // Error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Current category
  AnnouncementCategory _currentCategory = AnnouncementCategory.news;
  AnnouncementCategory get currentCategory => _currentCategory;

  bool _isDisposed = false;

  /// Fetch announcements by category
  Future<void> fetchAnnouncements({
    required AnnouncementCategory category,
  }) async {
    if (_isDisposed) return;

    _currentCategory = category;
    _state = AnnouncementState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _apiService.fetchAnnouncements(category: category);

      if (_isDisposed) return;

      _announcements = results;

      if (results.isEmpty) {
        _state = AnnouncementState.empty;
      } else {
        _state = AnnouncementState.loaded;
      }

      _errorMessage = null;
    } on AnnouncementApiException catch (e) {
      if (_isDisposed) return;

      _state = AnnouncementState.error;
      _errorMessage = e.message;
      _announcements = [];
    } catch (e) {
      if (_isDisposed) return;

      _state = AnnouncementState.error;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _announcements = [];
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Refresh announcements for current category
  Future<void> refresh() async {
    await fetchAnnouncements(category: _currentCategory);
  }

  /// Clear data and reset to idle state
  void clear() {
    if (_isDisposed) return;

    _state = AnnouncementState.idle;
    _announcements = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Check if currently loading
  bool get isLoading => _state == AnnouncementState.loading;

  /// Check if data is loaded
  bool get hasData =>
      _state == AnnouncementState.loaded && _announcements.isNotEmpty;

  /// Check if state is empty
  bool get isEmpty => _state == AnnouncementState.empty;

  /// Check if there's an error
  bool get hasError => _state == AnnouncementState.error;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
