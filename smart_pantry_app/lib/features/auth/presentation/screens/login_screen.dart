import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../dashboard/presentation/screens/main_shell.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConstants.baseUrl);
    String? testResult;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.dns_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Server Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Backend API URL for this app:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'API URL',
                    hintText: 'http://72.62.246.243:3074/api/v1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Hostinger Cloud', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          controller.text = 'http://72.62.246.243:3074/api/v1';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Wi-Fi Laptop', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          controller.text = 'http://172.16.1.156:5001/api/v1';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (testResult != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: testResult!.contains('Success') ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: testResult!.contains('Success') ? Colors.green : Colors.red,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: testResult!.contains('Success') ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isTesting
                    ? null
                    : () async {
                        setModalState(() {
                          isTesting = true;
                          testResult = 'Testing connection...';
                        });
                        try {
                          final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
                          final url = controller.text.trim();
                          final pingUrl = url.endsWith('/') ? '${url}auth/login' : '$url/auth/login';
                          await dio.post(pingUrl, data: {'email': 'ping', 'password': 'ping'});
                          setModalState(() {
                            isTesting = false;
                            testResult = 'Success: Server is reachable!';
                          });
                        } on DioException catch (dioErr) {
                          setModalState(() {
                            isTesting = false;
                            if (dioErr.response != null) {
                              testResult = 'Success: Server connected! (HTTP ${dioErr.response?.statusCode})';
                            } else {
                              testResult = 'Failed: ${dioErr.message ?? dioErr.error?.toString() ?? "Could not reach server"}';
                            }
                          });
                        } catch (err) {
                          setModalState(() {
                            isTesting = false;
                            testResult = 'Error: $err';
                          });
                        }
                      },
                child: isTesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Test Connection'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final newUrl = controller.text.trim();
                  if (newUrl.isNotEmpty) {
                    ApiConstants.setBaseUrl(newUrl);
                    await SecureStorageService().saveServerUrl(ApiConstants.baseUrl);
                    setState(() {});
                  }
                  if (mounted) Navigator.pop(dialogCtx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await ref.read(authControllerProvider.notifier).login(email, password);

      if (mounted) {
        ref.read(activeNavTabProvider.notifier).state = 0;
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login failed: ${e.toString().replaceAll("Exception:", "").trim()}',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: _showServerConfigDialog,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo / Icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.kitchen_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Smart Pantry',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your User ID & Password to continue',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // User ID / Email
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'User ID or Email',
                            hintText: 'e.g. staff_grocery or chef@smartpantry.local',
                            prefixIcon: const Icon(Icons.account_circle_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) =>
                              Validators.validateRequired(val, 'User ID or Email'),
                        ),
                        const SizedBox(height: 18),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) =>
                              Validators.validateRequired(val, 'Password'),
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 26),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 18),

                        // Server URL status & Change button
                        InkWell(
                          onTap: _showServerConfigDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.dns_rounded, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    ApiConstants.baseUrl,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.settings_outlined, size: 14, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
