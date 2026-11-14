import '../../domain/models/home_action_card.dart';

class HomeSummaryState {
  final bool isLoading;
  final HomeSummaryData? data;
  final String? errorMessage;
  final bool isGuest;
  final String? openingReportId;

  const HomeSummaryState({
    this.isLoading = false,
    this.data,
    this.errorMessage,
    this.isGuest = false,
    this.openingReportId,
  });

  List<HomeActionCard> get actionCards => data?.actionCards ?? const [];
  bool get hasCards => actionCards.isNotEmpty;

  HomeSummaryState copyWith({
    bool? isLoading,
    HomeSummaryData? data,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isGuest,
    String? openingReportId,
    bool clearOpeningReportId = false,
  }) {
    return HomeSummaryState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      isGuest: isGuest ?? this.isGuest,
      openingReportId: clearOpeningReportId ? null : openingReportId ?? this.openingReportId,
    );
  }
}
