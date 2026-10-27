import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class AccessTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureAccessTokenStore implements AccessTokenStore {
  SecureAccessTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'simrs_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class HospitalApiException implements Exception {
  const HospitalApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HospitalApiClient {
  HospitalApiClient({
    required this.baseUrl,
    AccessTokenStore? tokenStore,
    http.Client? client,
  })  : _tokenStore = tokenStore ?? SecureAccessTokenStore(),
        _client = client ?? http.Client();

  static String get configuredBaseUrl {
    const configured = String.fromEnvironment('SIMRS_API_BASE_URL');
    if (configured.isNotEmpty) return configured;

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    return '';
  }

  final String baseUrl;
  final AccessTokenStore _tokenStore;
  final http.Client _client;

  Future<String?> readToken() => _tokenStore.read();

  Future<void> saveToken(String token) => _tokenStore.write(token);

  Future<void> clearToken() => _tokenStore.delete();

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required Uint8List fileBytes,
    required String fileName,
    Map<String, String> fields = const {},
  }) async {
    final uri = _buildUri(path);
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const HospitalApiException('Silakan masuk kembali.', statusCode: 401);
    }
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
        ),
      );
    return _sendPrepared(request);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    required bool authenticated,
  }) async {
    final uri = _buildUri(path);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = await _tokenStore.read();
      if (token == null || token.isEmpty) {
        throw const HospitalApiException(
          'Silakan masuk kembali.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, uri)
      ..headers.addAll(headers)
      ..body = body == null ? '' : jsonEncode(body);
    return _sendPrepared(request);
  }

  Uri _buildUri(String path) {
    final configured = baseUrl.trim();
    if (configured.isEmpty) {
      throw const HospitalApiException(
        'Server belum dikonfigurasi. Atur SIMRS_API_BASE_URL saat menjalankan aplikasi.',
      );
    }
    final uri = Uri.parse('${configured.replaceFirst(RegExp(r'/+$'), '')}$path');
    final isLocalDevelopment = const {
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '::1',
    }.contains(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLocalDevelopment)) {
      throw const HospitalApiException(
        'Koneksi server harus menggunakan HTTPS.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> _sendPrepared(http.BaseRequest request) async {
    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 15),
          );
      response = await http.Response.fromStream(streamed).timeout(
            const Duration(seconds: 15),
          );
    } on TimeoutException {
      throw const HospitalApiException(
        'Server tidak merespons dalam batas waktu. Periksa koneksi lalu coba lagi.',
      );
    } on http.ClientException {
      throw const HospitalApiException(
        'Tidak dapat terhubung ke server rumah sakit. Periksa alamat server dan koneksi jaringan.',
      );
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respons API bukan objek JSON.');
      }
      payload = decoded;
    } on FormatException {
      throw HospitalApiException(
        'Server mengirim respons yang tidak dapat dibaca (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = payload['errors'];
      final validationMessage = errors is Map
          ? errors.values
              .whereType<List>()
              .expand((messages) => messages)
              .whereType<String>()
              .join('\n')
          : '';
      final message = validationMessage.isNotEmpty
          ? validationMessage
          : payload['message'] as String? ?? 'Server menolak permintaan.';
      throw HospitalApiException(message, statusCode: response.statusCode);
    }

    return payload;
  }
}
