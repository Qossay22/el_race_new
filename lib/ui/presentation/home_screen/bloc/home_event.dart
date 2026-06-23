part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

final class FetchLastMonthAttendanceSummary extends HomeEvent {
  const FetchLastMonthAttendanceSummary();
}

class ChangeCurrentIndex extends HomeEvent {
  final int index;
  const ChangeCurrentIndex({required this.index});
}

class ChangeVisiablityIcon extends HomeEvent {
  const ChangeVisiablityIcon();
}

class CheckInStatusChangedEvent extends HomeEvent {
  final bool isCheckedIn;
  const CheckInStatusChangedEvent(this.isCheckedIn);
  @override
  List<Object> get props => [isCheckedIn];
}

// Prayer Events
class InitPrayerTimesEvent extends HomeEvent {
  const InitPrayerTimesEvent();
}

class LoadPrayerMuteStateEvent extends HomeEvent {
  const LoadPrayerMuteStateEvent();
}

class TogglePrayerMuteStateEvent extends HomeEvent {
  const TogglePrayerMuteStateEvent();
}

class UpdatePrayerTickEvent extends HomeEvent {
  const UpdatePrayerTickEvent();
}

// App lifecycle event: re-schedule background prayer notifications
class AppPausedEvent extends HomeEvent {
  const AppPausedEvent();
}

// Reorder Mode Events
class ToggleReorderModeEvent extends HomeEvent {
  const ToggleReorderModeEvent();
}
