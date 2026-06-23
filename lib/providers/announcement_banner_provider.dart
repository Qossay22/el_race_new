import 'package:flutter/foundation.dart';
import 'package:el_race/data/models/announcement_details_model.dart';
import 'package:el_race/data/services/announcements_api_service.dart';

/// Banner state enumeration
enum BannerState {
  idle,
  loading,
  loaded,
  empty,
  error,
}

/// Provider for managing home banner/announcement details state
class AnnouncementBannerProvider extends ChangeNotifier {
  final AnnouncementsApiService _apiService;

  AnnouncementBannerProvider({AnnouncementsApiService? apiService})
      : _apiService = apiService ?? AnnouncementsApiService();

  // State
  BannerState _state = BannerState.idle;
  BannerState get state => _state;

  // Data
  AnnouncementDetailsModel? _bannerData;
  AnnouncementDetailsModel? get bannerData => _bannerData;

  // Error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isDisposed = false;

  /// Fetch announcement details for banner
  Future<void> fetchBannerData({required int announcementId}) async {
    if (_isDisposed) return;

    _state = BannerState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.fetchAnnouncementDetails(
        announcementId: announcementId,
      );

      if (_isDisposed) return;

      _bannerData = result;
      _state = BannerState.loaded;
      _errorMessage = null;
    } on AnnouncementApiException catch (e) {
      if (_isDisposed) return;

      _state = BannerState.error;
      _errorMessage = e.message;
      _bannerData = null;
    } catch (e) {
      if (_isDisposed) return;

      _state = BannerState.error;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _bannerData = null;
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Refresh banner data
  Future<void> refresh(int announcementId) async {
    await fetchBannerData(announcementId: announcementId);
  }

  /// Clear data and reset to idle state
  void clear() {
    if (_isDisposed) return;

    _state = BannerState.idle;
    _bannerData = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Check if currently loading
  bool get isLoading => _state == BannerState.loading;

  /// Check if has data
  bool get hasData => _state == BannerState.loaded && _bannerData != null;

  /// Check if has error
  bool get hasError => _state == BannerState.error;

  /// Check if empty
  bool get isEmpty => _state == BannerState.empty;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
