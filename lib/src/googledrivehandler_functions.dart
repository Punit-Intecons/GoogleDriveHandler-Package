import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'googledrivehandler_screen.dart';

class GoogleDriveHandler {
  GoogleDriveHandler._internal();
  static final GoogleDriveHandler _googleDriveHandler =
      GoogleDriveHandler._internal();
  factory GoogleDriveHandler() => _googleDriveHandler;

  google_sign_in.GoogleSignInAccount? account;
  final _googleSignIn = google_sign_in.GoogleSignIn.instance;
  bool _isInitialized = false;

  String? _googlDriveApiKey;

  setAPIKey({required String apiKey}) {
    _googlDriveApiKey = apiKey;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  Future getFileFromGoogleDrive({required BuildContext context}) async {
    if (_googlDriveApiKey != null) {
      await _signinUser();
      if (account != null) {
        return await _openGoogleDriveScreen(context);
      } else {
        log("Google Signin was declined by the user!");
      }
    } else {
      log('GOOGLEDRIVEAPIKEY has not yet been set. Please follow the documentation and call GoogleDriveHandler().setApiKey(YourAPIKey); to set your own API key');
    }
  }

  _openGoogleDriveScreen(BuildContext context) async {
    // Get access token for Drive API using the new authorization client
    final authClient = _googleSignIn.authorizationClient;
    final authorization =
        await authClient.authorizationForScopes([drive.DriveApi.driveScope]);

    if (authorization == null) {
      // Request authorization if not already granted
      final newAuth =
          await authClient.authorizeScopes([drive.DriveApi.driveScope]);
      if (newAuth == null) {
        log("Failed to get authorization for Drive API");
        return;
      }
    }

    final authHeaders = <String, String>{
      'Authorization': 'Bearer ${authorization?.accessToken ?? ''}',
    };

    final authenticateClient = _GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);
    drive.FileList fileList = await driveApi.files.list();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoogleDriveScreen(
          fileList: fileList,
          googleDriveApiKey: _googlDriveApiKey.toString(),
          authenticateClient: authenticateClient,
          userName: (account?.displayName ?? "").replaceAll(" ", ""),
        ),
      ),
    );
  }

  Future _signinUser() async {
    try {
      await _ensureInitialized();

      // Try lightweight authentication first (silent sign-in)
      final result = _googleSignIn.attemptLightweightAuthentication();
      if (result is Future<google_sign_in.GoogleSignInAccount?>) {
        account = await result;
      } else {
        account = result as google_sign_in.GoogleSignInAccount?;
      }

      // If silent sign-in failed, use full authentication
      if (account == null) {
        account = await _googleSignIn.authenticate(
          scopeHint: [drive.DriveApi.driveScope],
        );
      }
    } on google_sign_in.GoogleSignInException catch (e) {
      log('Google Sign-In error: ${e.code.name} - ${e.description}');
      account = null;
    } catch (e) {
      log('Unexpected error during Google Sign-In: $e');
      account = null;
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
