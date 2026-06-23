part of 'home_bloc.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

final class HomeInitial extends HomeState {}

final class CheckedInSTHome extends HomeState {}

final class CheckedOutSTHome extends HomeState {}

class LastMonthAttendanceSummaryLoading extends HomeState {
  const LastMonthAttendanceSummaryLoading();
}

class LastMonthAttendanceSummaryLoaded extends HomeState {
  const LastMonthAttendanceSummaryLoaded();

  @override
  List<Object> get props => [];
}

class LastMonthAttendanceSummaryError extends HomeState {
  final String message;
  const LastMonthAttendanceSummaryError(this.message);

  @override
  List<Object> get props => [message];
}

class ChangeIndexLoading extends HomeState {}

class ChangeIndexSuccess extends HomeState {}

// Prayer States
class PrayerTimesLoading extends HomeState {
  const PrayerTimesLoading();
}

class PrayerTimesLoaded extends HomeState {
  final dynamic prayerTimes;
  final dynamic nextPrayer;
  final DateTime? nextTime;
  final String? error;
  final bool isSoundMuted;
  final Map<String, DateTime>? aladhanTimes; // أوقات Aladhan API

  const PrayerTimesLoaded({
    required this.prayerTimes,
    required this.nextPrayer,
    required this.nextTime,
    this.error,
    required this.isSoundMuted,
    this.aladhanTimes,
  });

  PrayerTimesLoaded copyWith({
    dynamic prayerTimes,
    dynamic nextPrayer,
    DateTime? nextTime,
    String? error,
    bool? isSoundMuted,
    Map<String, DateTime>? aladhanTimes,
  }) {
    return PrayerTimesLoaded(
      prayerTimes: prayerTimes ?? this.prayerTimes,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      nextTime: nextTime ?? this.nextTime,
      error: error ?? this.error,
      isSoundMuted: isSoundMuted ?? this.isSoundMuted,
      aladhanTimes: aladhanTimes ?? this.aladhanTimes,
    );
  }
}

class PrayerTimesError extends HomeState {
  final String error;
  final dynamic prayerTimes;
  final bool isSoundMuted;

  const PrayerTimesError({
    required this.error,
    this.prayerTimes,
    required this.isSoundMuted,
  });
}

class PrayerMuteStateChanged extends HomeState {
  final bool isMuted;
  const PrayerMuteStateChanged(this.isMuted);

  @override
  List<Object> get props => [isMuted];
}

// Reorder Mode States
class ReorderModeChanged extends HomeState {
  final bool isReorderMode;
  const ReorderModeChanged(this.isReorderMode);

  @override
  List<Object> get props => [isReorderMode];
}
