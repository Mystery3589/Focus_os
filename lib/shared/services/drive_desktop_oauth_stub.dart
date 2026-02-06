import 'package:googleapis_auth/googleapis_auth.dart';

/// Starts an interactive desktop OAuth sign-in.
///
/// Returns [AccessCredentials] on success, or null if unsupported/cancelled.
Future<AccessCredentials?> signInDesktopLoopback({
  required ClientId clientId,
  required List<String> scopes,
}) async {
  return null;
}

/// Refreshes an access token using a stored refresh_token.
///
/// Returns updated [AccessCredentials], or null if unsupported/failed.
Future<AccessCredentials?> refreshDesktopCredentials({
  required ClientId clientId,
  required AccessCredentials credentials,
}) async {
  return null;
}
