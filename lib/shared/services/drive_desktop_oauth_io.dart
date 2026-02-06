import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'open_url.dart';

/// Desktop OAuth flow using a localhost loopback redirect.
///
/// This avoids copy/paste codes and works well for Windows desktop apps.
Future<AccessCredentials?> signInDesktopLoopback({
  required ClientId clientId,
  required List<String> scopes,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  final redirectUri = Uri.parse('http://${server.address.address}:${server.port}/');

  final state = _randomState();
  final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId.identifier,
    'redirect_uri': redirectUri.toString(),
    'response_type': 'code',
    'scope': scopes.join(' '),
    'access_type': 'offline',
    // Force refresh_token to be returned at least once.
    'prompt': 'consent',
    'include_granted_scopes': 'true',
    'state': state,
  });

  // Open the system browser.
  unawaited(openUrl(authUri.toString()));

  try {
    // Wait for the first redirect hit.
    final req = await server.first.timeout(const Duration(minutes: 2));
    final qp = req.uri.queryParameters;

    final returnedState = qp['state'];
    final error = qp['error'];
    final code = qp['code'];

    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.html;

    if (error != null && error.isNotEmpty) {
      req.response.write('<html><body><h3>Sign-in cancelled</h3><p>You can close this window.</p></body></html>');
      await req.response.close();
      return null;
    }

    if (returnedState != state || code == null || code.isEmpty) {
      req.response.write('<html><body><h3>Sign-in failed</h3><p>You can close this window and try again.</p></body></html>');
      await req.response.close();
      return null;
    }

    req.response.write('<html><body><h3>Signed in</h3><p>You can close this window and return to the app.</p></body></html>');
    await req.response.close();

    final token = await _exchangeCodeForToken(
      code: code,
      clientId: clientId,
      redirectUri: redirectUri.toString(),
    );

    if (token == null) return null;

    final accessToken = token.accessToken;
    final expiry = DateTime.now().toUtc().add(Duration(seconds: token.expiresIn));

    // Note: refresh_token may be missing if Google decides not to return it.
    // In that case, we still allow the session but it won't be restorable.
    final refreshToken = token.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return AccessCredentials(
        AccessToken('Bearer', accessToken, expiry),
        null,
        scopes,
      );
    }

    return AccessCredentials(
      AccessToken('Bearer', accessToken, expiry),
      refreshToken,
      scopes,
    );
  } finally {
    await server.close(force: true);
  }
}

Future<AccessCredentials?> refreshDesktopCredentials({
  required ClientId clientId,
  required AccessCredentials credentials,
}) async {
  final refreshToken = credentials.refreshToken;
  if (refreshToken == null || refreshToken.isEmpty) return null;

  final uri = Uri.parse('https://oauth2.googleapis.com/token');
  final resp = await http
      .post(
        uri,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId.identifier,
          'client_secret': clientId.secret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      )
      .timeout(const Duration(seconds: 30));

  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    return null;
  }

  final m = jsonDecode(resp.body) as Map<String, dynamic>;
  final at = (m['access_token'] ?? '') as String;
  final ei = (m['expires_in'] ?? 0) as int;
  if (at.isEmpty || ei <= 0) return null;

  final expiry = DateTime.now().toUtc().add(Duration(seconds: ei));
  return AccessCredentials(
    AccessToken('Bearer', at, expiry),
    refreshToken,
    credentials.scopes,
  );
}

String _randomState() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64Url.encode(bytes);
}

class _TokenResponse {
  final String accessToken;
  final int expiresIn;
  final String? refreshToken;

  const _TokenResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
  });
}

Future<_TokenResponse?> _exchangeCodeForToken({
  required String code,
  required ClientId clientId,
  required String redirectUri,
}) async {
  final uri = Uri.parse('https://oauth2.googleapis.com/token');

  final resp = await http
      .post(
        uri,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': clientId.identifier,
          'client_secret': clientId.secret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      )
      .timeout(const Duration(seconds: 30));

  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    return null;
  }

  final m = jsonDecode(resp.body) as Map<String, dynamic>;
  final at = (m['access_token'] ?? '') as String;
  final ei = (m['expires_in'] ?? 0) as int;
  final rt = m['refresh_token'] as String?;

  if (at.isEmpty || ei <= 0) return null;

  return _TokenResponse(accessToken: at, expiresIn: ei, refreshToken: rt);
}
