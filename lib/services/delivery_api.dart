import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryApiException implements Exception {
  DeliveryApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeliveryApi {
  DeliveryApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri _endpoint() {
    final base = dotenv.env['ADMIN_API_BASE_URL']?.trim() ?? '';
    if (base.isEmpty) {
      throw DeliveryApiException('Set ADMIN_API_BASE_URL in your local .env file.');
    }
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized/api/mobile/delivery');
  }

  Future<Map<String, dynamic>> _request(String method, {Map<String, dynamic>? body}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw DeliveryApiException('Your admin session has expired. Please sign in again.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = _endpoint();
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body));

    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) payload = decoded;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error']?.toString() ??
          'Delivery server request failed (${response.statusCode}).';
      throw DeliveryApiException(message);
    }
    return payload;
  }

  Future<Map<String, dynamic>> load() => _request('GET');
  Future<void> assign(String orderId, String partnerUid) async {
    await _request('POST', body: {'orderId': orderId, 'partnerUid': partnerUid});
  }
  Future<void> unassign(String orderId) async {
    await _request('POST', body: {'orderId': orderId, 'partnerUid': null});
  }
  void dispose() => _client.close();
}
