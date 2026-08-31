import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/appsync_manifest_service.dart';

class AwsLoginWebViewScreen extends StatefulWidget {
  const AwsLoginWebViewScreen({super.key});

  static Future<bool?> push(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AwsLoginWebViewScreen()),
    );
  }

  @override
  State<AwsLoginWebViewScreen> createState() => _AwsLoginWebViewScreenState();
}

class _AwsLoginWebViewScreenState extends State<AwsLoginWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isProcessingRedirect = false;
  String _currentUrl = '';
  String? _errorText;

  // The exact URL format extracted from the original dispatch loading app:
  // https://cabsystem.auth.eu-central-1.amazoncognito.com/oauth2/authorize
  //   ?client_id=78ikblrgsr8h27197iovkgrro6
  //   &response_type=code
  //   &scope=email+openid+aws.cognito.signin.user.admin
  //   &redirect_uri=myapp://
  static const String _authUrl =
      'https://cabsystem.auth.eu-central-1.amazoncognito.com/oauth2/authorize'
      '?client_id=78ikblrgsr8h27197iovkgrro6'
      '&response_type=code'
      '&scope=email+openid+aws.cognito.signin.user.admin'
      '&redirect_uri=myapp://';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _errorText = null;
              });
            }
            _interceptIfRedirect(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _currentUrl = url);
            _interceptIfRedirect(url);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) {
              if (mounted) setState(() => _currentUrl = url);
              _interceptIfRedirect(url);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Intercept the myapp:// redirect before the WebView tries to navigate to it
            if (url.startsWith('myapp://')) {
              _interceptIfRedirect(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            // The WebView will throw an error when it tries to load myapp:// — that's fine
            if (_currentUrl.startsWith('myapp://')) {
              _interceptIfRedirect(_currentUrl);
              return;
            }
            if (error.errorCode != -1 && !_isProcessingRedirect) {
              if (mounted) {
                setState(() => _errorText = 'Load error: ${error.description}');
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_authUrl));
  }

  void _interceptIfRedirect(String url) {
    if (_isProcessingRedirect) return;
    // Match myapp://?code=... pattern from original app
    if (url.startsWith('myapp://') || url.contains('?code=') || url.contains('&code=')) {
      _processRedirect(url);
    }
  }

  Future<void> _processRedirect(String url) async {
    if (_isProcessingRedirect) return;
    _isProcessingRedirect = true;

    AppHaptics.light();

    if (mounted) {
      setState(() => _errorText = null);
    }

    final success = await AppSyncManifestService.handleRedirectUrl(url);

    if (success) {
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Signed in! AWS credentials stored successfully.')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      _isProcessingRedirect = false;
      if (mounted) {
        setState(() => _errorText = 'Sign-in redirect received but token exchange failed. Please try again.');
      }
    }
  }

  void _reload() {
    _isProcessingRedirect = false;
    _controller.loadRequest(Uri.parse(_authUrl));
    if (mounted) setState(() => _errorText = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AWS Web Sign In',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Cognito Hosted UI / Microsoft SSO',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _reload,
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGlow,
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_errorText != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Retry', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
