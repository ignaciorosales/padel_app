import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';

part 'scoring_state.freezed.dart';

@freezed
class ScoringState with _$ScoringState {
  const factory ScoringState({
    required MatchScore match,
    @Default(<MatchScore>[]) List<MatchScore> undoStack,
    @Default(<MatchScore>[]) List<MatchScore> redoStack,
    @Default('') String lastActionLabel,
    @Default('') String lastAnnouncement,
    
    // Campos para mostrar el ganador del partido
    Team? matchWinner,
    @Default('') String matchWinnerName,
    @Default(false) bool matchCompleted,
  }) = _ScoringState;
}
