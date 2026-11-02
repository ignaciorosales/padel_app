import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:Puntazo/features/remote/remote_control_service.dart';

/// Ajustes ▸ Celular: activar el control desde el celular, el PIN del club y
/// el QR para conectarse.
///
/// El PIN no se muestra nunca: la tele la ve todo el público. El QR sólo
/// lleva la dirección, así que escanearlo sin saber el PIN no sirve de nada.
class RemoteSettingsTab extends StatefulWidget {
  const RemoteSettingsTab({super.key});

  @override
  State<RemoteSettingsTab> createState() => _RemoteSettingsTabState();
}

class _RemoteSettingsTabState extends State<RemoteSettingsTab> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _savePin(RemoteControlService remote) async {
    final hadPin = remote.hasPin;
    if (!RemoteControlService.isValidPin(_next.text)) {
      setState(() {
        _message = 'El PIN tiene que tener entre 4 y 8 números';
        _messageIsError = true;
      });
      return;
    }
    final ok = await remote.setPin(_next.text, current: _current.text);
    setState(() {
      _message = ok
          ? (hadPin
              ? 'PIN cambiado. Los celulares conectados tienen que volver a entrar.'
              : 'PIN guardado.')
          : 'El PIN actual no es correcto';
      _messageIsError = !ok;
      if (ok) {
        _current.clear();
        _next.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remote = context.read<RemoteControlService>();
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return ListenableBuilder(
      listenable: Listenable.merge([
        remote.enabled,
        remote.address,
        remote.connectedPhones,
        remote.error,
      ]),
      builder: (context, _) {
        final hasPin = remote.hasPin;
        final address = remote.address.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anotar desde el celular',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Una persona fuera de la pista anota los puntos, pone los '
                      'nombres y cambia de lado desde su celular. El celular y '
                      'la tele tienen que estar en la misma WiFi (o la tele '
                      'conectada al hotspot del celular). No hace falta internet.',
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      autofocus: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permitir control desde el celular'),
                      subtitle: hasPin ? null : const Text('Primero crea el PIN del club'),
                      value: remote.enabled.value,
                      onChanged: hasPin ? remote.setEnabled : null,
                    ),
                    const Divider(height: 24),
                    Text(
                      hasPin ? 'Cambiar el PIN del club' : 'Crear el PIN del club',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lo escribe el árbitro en su celular. Sólo lo sabe el club: '
                      'la tele nunca lo muestra.',
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (hasPin) ...[
                          _PinField(controller: _current, hint: 'PIN actual'),
                          const SizedBox(width: 12),
                        ],
                        _PinField(controller: _next, hint: 'PIN nuevo'),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => _savePin(remote),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _message!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _messageIsError ? Colors.redAccent : Colors.green,
                        ),
                      ),
                    ],
                    if (remote.error.value != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        remote.error.value!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              if (address != null)
                Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(8),
                      child: QrImageView(data: address, size: 180),
                    ),
                    const SizedBox(height: 8),
                    Text(address, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      switch (remote.connectedPhones.value) {
                        0 => 'Ningún celular conectado',
                        1 => '1 celular conectado',
                        final n => '$n celulares conectados',
                      },
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _PinField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
