import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manual trigger for the autonomous daily email report service.
///
/// The report itself is generated and sent by the GitHub Actions workflow
/// `.github/workflows/daily-report.yml` (scheduled weekdays at 06:00 SAST,
/// covering the previous working day). This service fires the same workflow
/// on demand from inside the app.
class ReportService {
  static const String repoOwner = 't-mpanza';
  static const String repoName = 'dispatch-logbook';
  static const String workflowFile = 'daily-report.yml';
  static const String defaultRecipient = 'Giz-MarieDP@att-tyres.co.za';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'report_github_token';

  /// Trigger the daily report workflow now.
  ///
  /// Returns a user-facing outcome: success message, or an error describing
  /// what is missing (e.g. no GitHub token configured).
  static Future<String> sendNow() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.trim().isEmpty) {
      return 'missing_token';
    }

    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$repoOwner/$repoName/actions/workflows/$workflowFile'
        '/dispatches',
      );
      final res = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'Authorization': 'Bearer ${token.trim()}',
              'User-Agent': 'DispatchDiary-App',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'ref': 'main'}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 204) {
        return 'ok';
      }
      debugPrint('Report dispatch failed (${res.statusCode}): ${res.body}');
      return 'failed:${res.statusCode}';
    } catch (e) {
      debugPrint('Report dispatch error: $e');
      return 'failed:0';
    }
  }

  static Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: trimmed);
    }
  }
}
