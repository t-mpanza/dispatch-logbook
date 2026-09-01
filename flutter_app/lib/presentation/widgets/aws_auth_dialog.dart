import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/services/appsync_manifest_service.dart';
import '../screens/aws_login_webview_screen.dart';

class AwsAuthDialog extends StatefulWidget {
  const AwsAuthDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AwsAuthDialog(),
    );
  }

  @override
  State<AwsAuthDialog> createState() => _AwsAuthDialogState();
}

class _AwsAuthDialogState extends State<AwsAuthDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _idTokenController = TextEditingController();
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _refreshTokenController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _errorMessage;
  String? _successMessage;
  AwsUserInfo _authInfo = const AwsUserInfo(isAuthenticated: false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    final info = await AppSyncManifestService.getAuthDetails();
    if (mounted) {
      setState(() {
        _authInfo = info;
      });
    }
  }

  Future<void> _handleWebSignIn() async {
    AppHaptics.light();
    final result = await AwsLoginWebViewScreen.push(context);
    if (result == true) {
      await _loadAuthStatus();
      if (mounted) {
        setState(() {
          _successMessage = 'Web sign-in successful! AWS credentials stored.';
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _handleDirectLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username/email and password.';
        _successMessage = null;
      });
      return;
    }

    AppHaptics.light();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final info = await AppSyncManifestService.loginWithCredentials(
        username: username,
        password: password,
      );
      AppHaptics.success();
      if (mounted) {
        setState(() {
          _authInfo = info;
          _successMessage = 'Successfully authenticated with AWS AppSync!';
          _passwordController.clear();
        });
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSaveTokens() async {
    final idToken = _idTokenController.text.trim();
    final accessToken = _accessTokenController.text.trim();
    final refreshToken = _refreshTokenController.text.trim();

    if (idToken.isEmpty) {
      setState(() {
        _errorMessage = 'ID Token is required for AppSync queries.';
        _successMessage = null;
      });
      return;
    }

    AppHaptics.light();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AppSyncManifestService.saveAuthTokens(
        accessToken: accessToken.isNotEmpty ? accessToken : idToken,
        idToken: idToken,
        refreshToken: refreshToken.isNotEmpty ? refreshToken : null,
      );

      final info = await AppSyncManifestService.getAuthDetails();
      AppHaptics.success();
      if (mounted) {
        setState(() {
          _authInfo = info;
          _successMessage = 'Auth tokens saved successfully!';
          _idTokenController.clear();
          _accessTokenController.clear();
          _refreshTokenController.clear();
        });
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save tokens: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleTestConnection() async {
    AppHaptics.light();
    setState(() {
      _isTestingConnection = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await AppSyncManifestService.testConnection();
    AppHaptics.medium();

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        if (success) {
          _successMessage = 'AppSync connection verified & active!';
        } else {
          _errorMessage = 'Connection test failed. Please verify credentials.';
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    AppHaptics.medium();
    await AppSyncManifestService.logout();
    await _loadAuthStatus();
    if (mounted) {
      setState(() {
        _successMessage = 'Logged out from AWS AppSync.';
        _errorMessage = null;
      });
    }
  }

  Future<void> _openHostedUI() async {
    final hostedUrl = AppSyncManifestService.getHostedUiAuthorizeUrl(tokenFlow: true);
    final uri = Uri.parse(hostedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _idTokenController.dispose();
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, color: AppColors.primaryGlow, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'AWS AppSync Authentication',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Connection Status Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _authInfo.isAuthenticated
                    ? Colors.greenAccent.withValues(alpha: 0.1)
                    : Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _authInfo.isAuthenticated
                      ? Colors.greenAccent.withValues(alpha: 0.3)
                      : Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _authInfo.isAuthenticated
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _authInfo.isAuthenticated ? Colors.greenAccent : Colors.redAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authInfo.isAuthenticated ? 'CONNECTED TO AWS' : 'NOT AUTHENTICATED',
                          style: TextStyle(
                            color: _authInfo.isAuthenticated ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _authInfo.isAuthenticated
                              ? (_authInfo.email ?? _authInfo.username ?? 'Active Session')
                              : 'Sign in to fetch live IBT manifests directly from AWS AppSync.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        if (_authInfo.expiresAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Session Expires: ${_authInfo.expiresAt!.toLocal()}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_authInfo.isAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      tooltip: 'Log Out',
                      onPressed: _handleLogout,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // PRIMARY ACTION: Web Login (Cognito Hosted UI / Microsoft SSO)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleWebSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGlow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.black, size: 20),
                label: const Text(
                  'Sign In with AWS Web Login (SSO)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Alerts
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Tab bar for Advanced / Alternative Sign-in methods
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Direct Login'),
                  Tab(text: 'Paste Token / SSO'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab Views
            SizedBox(
              height: 230,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Username & Password
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        label: 'Username / Work Email',
                        controller: _usernameController,
                        hint: 'e.g. neil@tredcor.co.za',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'Enter your password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleDirectLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Direct Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: Direct Token / SSO
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        label: 'ID Token (JWT)',
                        controller: _idTokenController,
                        hint: 'Paste eyJraWQiOiJ...',
                        icon: Icons.vpn_key_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: 'Refresh Token (Optional)',
                        controller: _refreshTokenController,
                        hint: 'Paste refresh token for auto-renewal',
                        icon: Icons.refresh_outlined,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _openHostedUI,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Open in Browser', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSaveTokens,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Save Tokens', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_authInfo.isAuthenticated) ...[
              const Divider(color: Colors.white10),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isTestingConnection ? null : _handleTestConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGlow))
                      : const Icon(Icons.wifi_tethering, size: 16, color: AppColors.primaryGlow),
                  label: const Text('Test Live AppSync Query Connection', style: TextStyle(color: AppColors.primaryGlow, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.white54, size: 16),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.glassSurfaceElevated,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryGlow),
            ),
          ),
        ),
      ],
    );
  }
}
