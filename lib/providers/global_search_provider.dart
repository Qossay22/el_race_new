import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/data/services/global_search_api_service.dart';

/// Search state enumeration
enum GlobalSearchState {
  idle,
  loading,
  loaded,
  empty,
  error,
}

/// Provider for managing global search state
class GlobalSearchProvider extends ChangeNotifier {
  final GlobalSearchApiService _apiService;

  GlobalSearchProvider({GlobalSearchApiService? apiService})
      : _apiService = apiService ?? GlobalSearchApiService();

  // State
  GlobalSearchState _state = GlobalSearchState.idle;
  GlobalSearchState get state => _state;

  // Results
  List<GlobalSearchItem> _results = [];
  List<GlobalSearchItem> get results => _results;

  // Error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Current search parameters
  String _currentKeyword = '';
  String _currentCategory = '';

  String get currentKeyword => _currentKeyword;
  String get currentCategory => _currentCategory;

  // Debounce timer
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // For canceling previous requests
  bool _isDisposed = false;

  /// Perform search with debounce
  ///
  /// [category]: One of petty_cash, projects, lpo, notes, documents, tasks
  /// [keyword]: Search keyword
  /// [limit]: Maximum results (default 10)
  void search({
    required String category,
    required String keyword,
    int limit = 10,
  }) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Clear results if keyword is empty
    if (keyword.trim().isEmpty) {
      _clearResults();
      return;
    }

    // Minimum keyword length check
    if (keyword.trim().length < 2) {
      _clearResults();
      return;
    }

    // Set loading state immediately for better UX
    if (_state != GlobalSearchState.loading) {
      _setState(GlobalSearchState.loading);
    }

    _currentKeyword = keyword;
    _currentCategory = category;

    // Debounce search
    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(
        category: category,
        keyword: keyword,
        limit: limit,
      );
    });
  }

  /// Perform immediate search (without debounce)
  Future<void> searchImmediate({
    required String category,
    required String keyword,
    int limit = 10,
  }) async {
    _debounceTimer?.cancel();

    if (keyword.trim().isEmpty) {
      _clearResults();
      return;
    }

    _currentKeyword = keyword;
    _currentCategory = category;

    await _performSearch(
      category: category,
      keyword: keyword,
      limit: limit,
    );
  }

  /// Internal method to perform actual search
  Future<void> _performSearch({
    required String category,
    required String keyword,
    int limit = 10,
  }) async {
    if (_isDisposed) return;

    try {
      _setState(GlobalSearchState.loading);
      _errorMessage = null;

      final results = await _apiService.globalSearch(
        category: category,
        keyword: keyword,
        limit: limit,
      );

      if (kDebugMode && results.isNotEmpty && category == 'lpo') {
        debugPrint(
            '[GlobalSearch] LPO sample item: ${results.first.additionalData}');
      }

      if (_isDisposed) return;

      _results = results;

      if (results.isEmpty) {
        _setState(GlobalSearchState.empty);
      } else {
        _setState(GlobalSearchState.loaded);
      }
    } on GlobalSearchApiException catch (e) {
      if (_isDisposed) return;
      _errorMessage = e.message;
      _results = [];
      _setState(GlobalSearchState.error);
    } catch (e) {
      if (_isDisposed) return;
      _errorMessage = 'An unexpected error occurred';
      _results = [];
      _setState(GlobalSearchState.error);
      debugPrint('GlobalSearchProvider error: $e');
    }
  }

  /// Retry last search
  Future<void> retry() async {
    if (_currentKeyword.isNotEmpty && _currentCategory.isNotEmpty) {
      await searchImmediate(
        category: _currentCategory,
        keyword: _currentKeyword,
      );
    }
  }

  /// Clear search results and reset to idle state
  void clearResults() {
    _clearResults();
  }

  void _clearResults() {
    _debounceTimer?.cancel();
    _results = [];
    _errorMessage = null;
    _currentKeyword = '';
    _currentCategory = '';
    _setState(GlobalSearchState.idle);
  }

  /// Update state and notify listeners
  void _setState(GlobalSearchState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Check if currently searching
  bool get isLoading => _state == GlobalSearchState.loading;

  /// Check if has results
  bool get hasResults => _results.isNotEmpty;

  /// Check if in error state
  bool get hasError => _state == GlobalSearchState.error;

  /// Check if empty state
  bool get isEmpty => _state == GlobalSearchState.empty;

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
