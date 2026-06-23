import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:flutter/material.dart';

mixin MyActionsPaginationMixin<T extends StatefulWidget> on State<T> {
  final MyActionsRepository actionsRepository = MyActionsRepository();
  final ScrollController actionsScrollController = ScrollController();
  final List<MyActionItem> actionItems = <MyActionItem>[];

  bool actionsInitialLoading = true;
  bool actionsLoadingMore = false;
  bool actionsHasMore = true;
  Object? actionsError;
  Object? actionsLoadMoreError;

  int _actionsPage = 1;
  int _actionsRequestSerial = 0;

  MyActionsType get actionsType;

  void initActionsPagination() {
    actionsScrollController.addListener(_onActionsScroll);
    _loadActionsPage(reset: true);
  }

  void disposeActionsPagination() {
    actionsScrollController
      ..removeListener(_onActionsScroll)
      ..dispose();
  }

  Future<void> refreshActions() => _loadActionsPage(reset: true);

  Future<void> retryInitialActionsLoad() => _loadActionsPage(reset: true);

  Future<void> retryActionsLoadMore() => _loadActionsPage();

  Widget buildActionsPaginationFooter() {
    if (actionsLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (actionsLoadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton(
            onPressed: retryActionsLoadMore,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }

  void _onActionsScroll() {
    if (!actionsScrollController.hasClients ||
        actionsInitialLoading ||
        actionsLoadingMore ||
        !actionsHasMore) {
      return;
    }

    final position = actionsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadActionsPage();
    }
  }

  Future<void> _loadActionsPage({bool reset = false}) async {
    if (actionsLoadingMore && !reset) return;

    final nextPage = reset ? 1 : _actionsPage + 1;
    final requestSerial =
        reset ? ++_actionsRequestSerial : _actionsRequestSerial;

    setState(() {
      if (reset) {
        actionsInitialLoading = true;
        actionsLoadingMore = false;
        actionsHasMore = true;
        actionsError = null;
        actionsLoadMoreError = null;
        actionItems.clear();
        _actionsPage = 1;
      } else {
        actionsLoadingMore = true;
        actionsLoadMoreError = null;
      }
    });

    try {
      final pageItems = await actionsRepository.fetchByType(
        actionsType,
        page: nextPage,
        perPage: MyActionsRepository.defaultPerPage,
      );

      if (!mounted || requestSerial != _actionsRequestSerial) return;
      final keepOffset = !reset && actionsScrollController.hasClients
          ? actionsScrollController.offset
          : null;
      setState(() {
        if (reset) {
          actionItems
            ..clear()
            ..addAll(pageItems);
        } else {
          actionItems.addAll(pageItems);
        }
        _actionsPage = nextPage;
        actionsHasMore = pageItems.length == MyActionsRepository.defaultPerPage;
        actionsInitialLoading = false;
        actionsLoadingMore = false;
        actionsError = null;
        actionsLoadMoreError = null;
      });
      if (keepOffset != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !actionsScrollController.hasClients) return;
          final maxOffset = actionsScrollController.position.maxScrollExtent;
          actionsScrollController.jumpTo(
            keepOffset.clamp(0.0, maxOffset).toDouble(),
          );
        });
      }
    } catch (e) {
      if (!mounted || requestSerial != _actionsRequestSerial) return;
      setState(() {
        if (reset) {
          actionsError = e;
          actionsInitialLoading = false;
        } else {
          actionsLoadMoreError = e;
          actionsLoadingMore = false;
        }
      });
    }
  }
}
