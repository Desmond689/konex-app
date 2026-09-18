import '../services/connectivity_service.dart';

class NetworkInfo {
  NetworkInfo(this._connectivity);
  final ConnectivityService _connectivity;

  Future<bool> get isConnected => _connectivity.isConnected;
}
