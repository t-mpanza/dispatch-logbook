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

  @override
  void initState() {
    super.initState();
    final authUrl = AppSyncManifestService.getHostedUiAuthorizeUrl(tokenFlow: true);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.backgroundSecondary)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onPageStarted: (String url) {
            _checkAndInterceptUrl(url);
          },
          onPageFinished: (String url) {
            _checkAndInterceptUrl(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _checkAndInterceptUrl(change.url!);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkAndInterceptUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  bool _checkAndInterceptUrl(String url) {
    if (_isProcessingRedirect) return true;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (uri.scheme == 'myapp' ||
        uri.host == 'localhost' ||
        url.contains('id_token=') ||
        url.contains('code=')) {
      _processRedirect(url);
      return true;
    }
    return false;
  }

  Future<void> _processRedirect(String url) async {
    if (_isProcessingRedirect) return;
    _isProcessingRedirect = true;

    AppHaptics.light();
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
                Text('AWS AppSync credentials saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      _isProcessingRedirect = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.0),
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
      body: WebViewWidget(controller: _controller),
    );
  }
}
