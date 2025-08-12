import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Vosk (free, offline)
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padel Voice (Android)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const SpeechPage(),
    );
  }
}

enum Mode { wake, dictation }

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key});
  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
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

  // ======= LÓGICA DE DECISIÓN (corregida) =======
  bool _awaitingDecision = false;     // esperando VoskResult para confirmar/descartar
  bool? _keywordConfirmed;            // null=sin decisión; true=confirmado; false=negado
  String _sttLastHeard = '';          // último texto oído (parcial o final)
  String? _sttFinalCached;            // final “confirmable”
  bool _sttEnded = false;             // terminó la ventana STT
  Timer? _decisionTimer;              // espera a VoskResult después de que termine STT
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

            // ⚠️ Si no llegó un final “oficial”, promovemos el último oído como final
            if (_sttFinalCached == null && _sttLastHeard.trim().isNotEmpty) {
              _sttFinalCached = _sttLastHeard;
            }

            // Si no hay decisión aún, espera breve por VoskResult; si no llega, descarta
            _maybeCommitOrWait(startDecisionTimeout: true);

            // Volvemos a wake cuando cierre STT (commit o discard resuelven estado)
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

  // --------- Parciales: arrancan STT PROVISIONAL ----------
  void _onVoskPartial(String partialJson) {
    try {
      final t = (jsonDecode(partialJson)['partial'] as String?)?.toLowerCase().trim() ?? '';
      final now = DateTime.now();
      if (_mode != Mode.wake || _transitioning) return;
      if (t.isEmpty) return;

      if (_debugWake) print('[VoskPartial] "$t"');
      _lastPartial = t;
      _lastPartialAt = now;

      // Path 1: exacto con límites, dos rápidos → TRIGGER
      if (_isExactBoundary(t)) {
        _recordExact(now);
        if (_hasTwoExactWithinWindow(now) && !_inCooldown(now)) {
          if (_debugWake) print('[Wake] TRIGGER provisional (exact-burst)');
          _beginProvisionalDictation('exact-burst');
          return;
        }
      }

      if (t.length < 6) return;

      // Path 2: fuzzy + estabilidad → TRIGGER
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

  // --------- Resultado FINAL: confirma o descarta ----------
  void _onVoskResult(String resultJson) {
    try {
      final t = (jsonDecode(resultJson)['text'] as String?)?.toLowerCase().trim() ?? '';
      if (_debugWake) print('[VoskResult] "$t"');
      if (t.isEmpty) return;

      final isExact = _kwBoundary.hasMatch(t);
      if (_awaitingDecision) {
        _keywordConfirmed = isExact; // true=CONFIRM, false=REJECT
        _maybeCommitOrWait();
      }
      // Si llega un final exacto sin provisional, podrías iniciar directo; aquí lo ignoramos.
    } catch (e) {
      if (_debugWake) print('[VoskResult][ERR] $e');
    }
  }

  // ======= Decisión y commits (ARREGLADO) =======
  void _maybeCommitOrWait({bool startDecisionTimeout = false}) {
    // Confirmado + ya tenemos final -> COMMIT
    if (_keywordConfirmed == true && (_sttFinalCached ?? '').trim().isNotEmpty) {
      _cancelDecisionTimer();
      if (_debugWake) print('[BUSINESS] COMMIT: "${_sttFinalCached!}"');
      _processFinalText(_sttFinalCached!);
      _resetDecisionState();
      return;
    }

    // Negado -> DESCARTAR (pares STT si aún activo)
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

    // Aún sin decisión: si STT terminó y no hay confirmación, espera breve por VoskResult
    if (startDecisionTimeout && _sttEnded && _keywordConfirmed == null) {
      _decisionTimer ??= Timer(_decisionWait, () {
        // Tiempo agotado sin VoskResult -> descarta
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

  // ======= Arranque de dictado provisional =======
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

    // Estado de decisión
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

  // ======= Helpers de matching =======
  bool _isExactBoundary(String s) => _kwBoundary.hasMatch(s);
  bool _looksLikeFuzzy(String s) {
    if (_isExactBoundary(s)) return true;
    if (s.contains(_keyword)) return true;
    return _levenshteinLe1(s, _keyword) <= 1;
  }
  bool _inCooldown(DateTime now) =>
      _lastTriggerAt != null && now.difference(_lastTriggerAt!) < _cooldown;

  void _recordExact(DateTime now) {
    _exactHits.add(now);
    _pruneExact(now);
  }
  void _pruneExact(DateTime now) {
    _exactHits.removeWhere((t) => now.difference(t) > _exactBurstWindow);
  }
  bool _hasTwoExactWithinWindow(DateTime now) {
    _pruneExact(now);
    return _exactHits.length >= 2;
  }

  // Levenshtein ≤1 con escape temprano
  int _levenshteinLe1(String a, String b) {
    a = a.trim();
    b = b.trim();
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
        curr[c] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > 1) return 2;
      for (var i = 0; i < cols; i++) {
        final t = prev[i];
        prev[i] = curr[i];
        curr[i] = t;
      }
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
        _sttLastHeard = text; // <-- SIEMPRE guardamos lo último oído
        setState(() {
          _words = text;      // UI
          _isListening = _stt.isListening;
        });

        if (r.finalResult) {
          // Si llega finalResult, cacheamos y vemos si ya hay decisión
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

  // ======= Tu lógica de negocio, tras confirmación =======
  void _processFinalText(String text) {
    if (_debugWake) print('[BUSINESS] final text used: "$text"');
    // TODO: parsear e incrementar marcador, etc.
  }

  @override
  Widget build(BuildContext context) {
    final isWake = _mode == Mode.wake;
    return Scaffold(
      appBar: AppBar(title: const Text('Padel Voice (Android)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        !_engineReady
                            ? 'Initializing…'
                            : isWake
                                ? 'Wake mode: diga “marcador”'
                                : 'Dictation: hable ahora',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _words.isEmpty ? 'Transcripciones aquí…' : _words,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mode: ${isWake ? "wake" : "dictation"}'
                ' | awaitingDecision: $_awaitingDecision'
                ' | confirmed: $_keywordConfirmed',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_engineReady
          ? null
          : FloatingActionButton.extended(
              onPressed: isWake ? () => _beginProvisionalDictation('manual')
                                 : _stopAll,
              icon: Icon(isWake ? Icons.mic : Icons.stop),
              label: Text(isWake ? 'Start (manual)' : 'Stop'),
            ),
    );
  }
}
