import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silencia el plugin de audio en los tests.
///
/// Construir un `AudioPlayer` habla con los canales nativos de audioplayers,
/// que no existen bajo `flutter test`: sin esto, crear un [ScoringBloc] revienta
/// con MissingPluginException al primer punto. Llamar al principio de `main()`
/// en cualquier test que anote puntos.
void stubAudioPlayers() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}
