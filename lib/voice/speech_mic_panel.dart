import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

import 'voice_bridge.dart';

enum Mode { wake, dictation }

class SpeechMicPanel extends StatefulWidget {
  const SpeechMicPanel({super.key});
  @override
  State<SpeechMicPanel> createState() => _SpeechMicPanelState();
}

class _SpeechMicPanelState extends State<SpeechMicPanel> {
  // Engines
  final stt.SpeechToText _stt = stt.SpeechToText();
  final _vosk = VoskFlutterPlugin.instance();

  // Vosk
  Model? _voskModel;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  // UI / state
  bool _engineReady = false;
  bool _isListening = false;
  String _words = '';
  String _status = '';
  Mode _mode = Mode.wake;

  // Config
  static const int _sampleRate = 16000;
  static const Duration dictationWindow = Duration(seconds: 8);
  static const Duration pauseMax = Duration(seconds: 8);

  // Wake detection
  static const String _keyword = 'marcador';
  static final RegExp _kwBoundary =
      RegExp(r'\bmarcador(?:es)?\b', caseSensitive: false);
  static const Duration _partialStableFor = Duration(milliseconds: 150);
  static const Duration _partialFreshWindow = Duration(milliseconds: 750);
  static const Duration _exactBurstWindow = Duration(milliseconds: 650);
  static const Duration _cooldown = Duration(milliseconds: 1200);

  // Control
  Timer? _hardStop;
  Timer? _partialGateTimer;
  String _lastPartial = '';
  DateTime? _lastPartialAt;
  DateTime? _lastTriggerAt;
  bool _transitioning = false;
  final List<DateTime> _exactHits = <DateTime>[];

  // Decision logic (confirmed wake or not)
  bool _awaitingDecision = false;
  bool? _keywordConfirmed; // true confirm / false reject / null undecided
  String _sttLastHeard = '';
  String? _sttFinalCached;
  bool _sttEnded = false;
  Timer? _decisionTimer;
  static const Duration _decisionWait = Duration(milliseconds: 1200);

  // Debug
  static const bool _debugWake = true;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    try {
      final modelPath = await ModelLoader()
          .loadFromAssets('assets/models/vosk-model-small-es-0.42.zip');
      _voskModel = await _vosk.createModel(modelPath);

      _recognizer = await _vosk.createRecognizer(
        model: _voskModel!,
        sampleRate: _sampleRate,
        grammar: const ['marcador'],
      );

      _speechService = await _vosk.initSpeechService(_recognizer!);
      _speechService!.onPartial().listen(_onVoskPartial, onError: (_) {});
      _speechService!.onResult().listen(_onVoskResult, onError: (_) {});

      final ready = await _stt.initialize(
        onStatus: (s) async {
          if (_debugWake) print('[STT][status] $s');
          setState(() => _status = s);

          if (_mode == Mode.dictation && (s == 'notListening' || s == 'done')) {
            _sttEnded = true;

            // Promote last heard as final if needed
            if (_sttFinalCached == null && _sttLastHeard.trim().isNotEmpty) {
              _sttFinalCached = _sttLastHeard;
            }

            _maybeCommitOrWait(startDecisionTimeout: true);
            await _resumeWake();
          }
        },
        onError: (e) => setState(() => _status = 'STT error: ${e.errorMsg}'),
      );
      setState(() => _engineReady = ready);

      await _startWake();
    } catch (e, st) {
      setState(() {
        _status = 'Init error: $e';
        _engineReady = false;
      });
      if (_debugWake) print(st);
    }
  }

  // --------- Vosk partials: may start provisional dictation ----------
  void _onVoskPartial(String partialJson) {
    try {
      final t = (jsonDecode(partialJson)['partial'] as String?)?.toLowerCase().trim() ?? '';
      final now = DateTime.now();
      if (_mode != Mode.wake || _transitioning) return;
      if (t.isEmpty) return;

      if (_debugWake) print('[VoskPartial] "$t"');
      _lastPartial = t;
      _lastPartialAt = now;

      // Path 1: exact burst (two quick boundary matches)
      if (_isExactBoundary(t)) {
        _recordExact(now);
        if (_hasTwoExactWithinWindow(now) && !_inCooldown(now)) {
          if (_debugWake) print('[Wake] TRIGGER provisional (exact-burst)');
          _beginProvisionalDictation('exact-burst');
          return;
        }
      }

      if (t.length < 6) return;

      // Path 2: fuzzy + stability
      if (_looksLikeFuzzy(t)) {
        _partialGateTimer?.cancel();
        _partialGateTimer = Timer(_partialStableFor, () {
          final fresh = _lastPartialAt != null &&
              DateTime.now().difference(_lastPartialAt!) <= _partialFreshWindow;
          if (_mode == Mode.wake &&
              !_transitioning &&
              fresh &&
              _looksLikeFuzzy(_lastPartial) &&
              !_inCooldown(DateTime.now())) {
            if (_debugWake) print('[Wake] TRIGGER provisional (fuzzy-stable)');
            _beginProvisionalDictation('fuzzy-stable');
          }
        });
      }
    } catch (e) {
      if (_debugWake) print('[VoskPartial][ERR] $e');
    }
  }

  // --------- Vosk final: confirm or reject ----------
  void _onVoskResult(String resultJson) {
    try {
      final t = (jsonDecode(resultJson)['text'] as String?)?.toLowerCase().trim() ?? '';
      if (_debugWake) print('[VoskResult] "$t"');
      if (t.isEmpty) return;

      final isExact = _kwBoundary.hasMatch(t);
      if (_awaitingDecision) {
        _keywordConfirmed = isExact;
        _maybeCommitOrWait();
      }
    } catch (e) {
      if (_debugWake) print('[VoskResult][ERR] $e');
    }
  }

  // ======= Decision & commit =======
  void _maybeCommitOrWait({bool startDecisionTimeout = false}) {
    // Confirmed and we have final STT -> commit
    if (_keywordConfirmed == true && (_sttFinalCached ?? '').trim().isNotEmpty) {
      _cancelDecisionTimer();
      if (_debugWake) print('[BUSINESS] COMMIT: "${_sttFinalCached!}"');
      _processFinalText(_sttFinalCached!);
      _resetDecisionState();
      return;
    }

    // Rejected -> discard
    if (_keywordConfirmed == false) {
      _cancelDecisionTimer();
      if (_debugWake) print('[BUSINESS] REJECT: discard phrase');
      _resetDecisionState();
      if (_mode == Mode.dictation && _stt.isListening) {
        _stt.stop();
      }
      setState(() => _words = '');
      return;
    }

    // Wait briefly for VoskResult after STT ends
    if (startDecisionTimeout && _sttEnded && _keywordConfirmed == null) {
      _decisionTimer ??= Timer(_decisionWait, () {
        if (_debugWake) print('[BUSINESS] TIMEOUT waiting VoskResult -> discard');
        _keywordConfirmed = false;
        _maybeCommitOrWait();
      });
    }
  }

  void _cancelDecisionTimer() {
    _decisionTimer?.cancel();
    _decisionTimer = null;
  }

  // ======= Start provisional dictation =======
  Future<void> _beginProvisionalDictation(String reason) async {
    if (_mode == Mode.dictation || _transitioning) return;
    _transitioning = true;

    final now = DateTime.now();
    if (_inCooldown(now)) {
      if (_debugWake) print('[Wake] cooldown-hit ($reason)');
      _transitioning = false;
      return;
    }
    _lastTriggerAt = now;

    _awaitingDecision = true;
    _keywordConfirmed = null;
    _sttFinalCached = null;
    _sttLastHeard = '';
    _sttEnded = false;
    _cancelDecisionTimer();

    if (_debugWake) print('[Wake] ENTER dictation (provisional, reason=$reason)');
    await _enterDictation();
    _transitioning = false;
  }

  // ======= Helpers =======
  bool _isExactBoundary(String s) => _kwBoundary.hasMatch(s);
  bool _looksLikeFuzzy(String s) {
    if (_isExactBoundary(s)) return true;
    if (s.contains(_keyword)) return true;
    return _levenshteinLe1(s, _keyword) <= 1;
  }
  bool _inCooldown(DateTime now) =>
      _lastTriggerAt != null && now.difference(_lastTriggerAt!) < _cooldown;

  void _recordExact(DateTime now) {
    _exactHits.add(now); _pruneExact(now);
  }
  void _pruneExact(DateTime now) {
    _exactHits.removeWhere((t) => now.difference(t) > _exactBurstWindow);
  }
  bool _hasTwoExactWithinWindow(DateTime now) {
    _pruneExact(now); return _exactHits.length >= 2;
  }

  // Levenshtein ≤1
  int _levenshteinLe1(String a, String b) {
    a = a.trim(); b = b.trim();
    if (a == b) return 0;
    if (a.isEmpty || b.isEmpty) return (a.isEmpty ? b.length : a.length) <= 1 ? 1 : 2;
    if ((a.length - b.length).abs() > 1) return 2;
    final rows = a.length + 1, cols = b.length + 1;
    final prev = List<int>.generate(cols, (i) => i);
    final curr = List<int>.filled(cols, 0);
    for (var r = 1; r < rows; r++) {
      curr[0] = r;
      final ca = a.codeUnitAt(r - 1);
      var rowMin = curr[0];
      for (var c = 1; c < cols; c++) {
        final cb = b.codeUnitAt(c - 1);
        final cost = (ca == cb) ? 0 : 1;
        final del = prev[c] + 1;
        final ins = curr[c - 1] + 1;
        final sub = prev[c - 1] + cost;
        final v = (del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub));
        curr[c] = v; if (v < rowMin) rowMin = v;
      }
      if (rowMin > 1) return 2;
      for (var i = 0; i < cols; i++) { final t = prev[i]; prev[i] = curr[i]; curr[i] = t; }
    }
    return prev.last;
  }

  // ======= STT / wake lifecycle =======
  Future<void> _enterDictation() async {
    if (!_engineReady) return;
    await _stopWake();

    final locale = await _stt.systemLocale(); // es-ES / es-419 etc.
    await _stt.listen(
      onResult: (r) {
        final text = r.recognizedWords;
        _sttLastHeard = text;
        setState(() {
          _words = text;
          _isListening = _stt.isListening;
        });
        if (r.finalResult) {
          _sttFinalCached = text;
          _maybeCommitOrWait();
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      localeId: locale?.localeId,
      pauseFor: pauseMax,
      listenFor: dictationWindow,
    );

    setState(() {
      _mode = Mode.dictation;
      _status = 'dictation';
      _isListening = true;
    });

    _hardStop?.cancel();
    _hardStop = Timer(dictationWindow + const Duration(seconds: 1), () async {
      if (_mode == Mode.dictation) await _stt.stop();
    });
  }

  Future<void> _startWake() async {
    if (_speechService == null) return;
    _partialGateTimer?.cancel();
    _lastPartial = '';
    _lastPartialAt = null;
    _exactHits.clear();
    _resetDecisionState();

    await _speechService!.start();
    setState(() {
      _mode = Mode.wake;
      _isListening = true;
      _status = 'wake (vosk)';
    });
  }

  Future<void> _stopWake() async {
    if (_speechService == null) return;
    await _speechService!.stop();
    setState(() => _isListening = false);
  }

  Future<void> _resumeWake() async {
    _hardStop?.cancel();
    _cancelDecisionTimer();
    await _startWake();
  }

  Future<void> _stopAll() async {
    _hardStop?.cancel();
    _partialGateTimer?.cancel();
    _cancelDecisionTimer();
    try {
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
    await _startWake();
  }

  void _resetDecisionState() {
    _awaitingDecision = false;
    _keywordConfirmed = null;
    _sttLastHeard = '';
    _sttFinalCached = null;
    _sttEnded = false;
    _cancelDecisionTimer();
  }

  @override
  void dispose() {
    _hardStop?.cancel();
    _partialGateTimer?.cancel();
    _cancelDecisionTimer();
    _stt.stop();
    _speechService?.stop();
    _speechService?.dispose();
    _recognizer?.dispose();
    _voskModel?.dispose();
    super.dispose();
  }

  // ======= Business: parsed commands -> Bloc =======
  void _processFinalText(String text) {
    if (_debugWake) print('[BUSINESS] final text used: "$text"');
    processFinalVoiceText(context, text); // <- dispatch to scoring BLoC
  }

  @override
  Widget build(BuildContext context) {
    final isWake = _mode == Mode.wake;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
            title: Text(
              !_engineReady
                  ? 'Inicializando…'
                  : isWake ? 'Wake: diga “marcador”' : 'Dictado activo: hable ahora',
            ),
            subtitle: Text('estado: $_status'
                ' | decisión: ${_awaitingDecision ? "pendiente" : (_keywordConfirmed == true ? "confirmada" : _keywordConfirmed == false ? "negada" : "-")}'),
            trailing: isWake
                ? FilledButton.icon(
                    onPressed: () => _beginProvisionalDictation('manual'),
                    icon: const Icon(Icons.mic),
                    label: const Text('Hablar'),
                  )
                : FilledButton.icon(
                    onPressed: _stopAll,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(minHeight: 90, maxHeight: 160),
          child: SingleChildScrollView(
            child: Text(
              _words.isEmpty ? 'Transcripciones aquí…' : _words,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
