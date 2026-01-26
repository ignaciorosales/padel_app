import 'package:flutter_bloc/flutter_bloc.dart';

/// Estado de conexión USB
class UsbConnectionState {
  final bool isConnected;

  const UsbConnectionState({this.isConnected = false});

  UsbConnectionState copyWith({bool? isConnected}) {
    return UsbConnectionState(isConnected: isConnected ?? this.isConnected);
  }
}

/// Cubit para manejar el estado de conexión USB
class UsbConnectionCubit extends Cubit<UsbConnectionState> {
  UsbConnectionCubit() : super(const UsbConnectionState());

  void setConnected(bool connected) {
    emit(state.copyWith(isConnected: connected));
  }
}
