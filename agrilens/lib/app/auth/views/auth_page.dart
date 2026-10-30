import 'package:agrilens/app/auth/services/auth_service.dart';
import 'package:agrilens/app/weather/services/weather_location_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/shared/components/custom_filled_btn.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/components/custom_textfield.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.authService,
    required this.isRegister,
    this.weatherLocationService = const WeatherLocationService(),
  });

  final AuthService authService;
  final bool isRegister;
  final WeatherLocationService weatherLocationService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _locationMessage;
  bool _requestingLocation = false;
  bool _locationSettingsRequired = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enableWeatherLocation() async {
    if (_requestingLocation) return;
    setState(() {
      _requestingLocation = true;
      _locationMessage = null;
      _locationSettingsRequired = false;
    });
    try {
      await widget.weatherLocationService.requestAndSave();
      if (mounted) {
        setState(() => _locationMessage = 'Location saved for local weather.');
      }
    } on WeatherLocationException catch (error) {
      if (mounted) {
        setState(() {
          _locationMessage = error.message;
          _locationSettingsRequired =
              error.failure == WeatherLocationFailure.deniedForever;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _locationMessage =
                  'Could not get your location. You can try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (widget.isRegister) {
        await widget.authService.register(email: email, password: password);
      } else {
        await widget.authService.signIn(email: email, password: password);
      }
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error is ApiRequestException
                  ? error.message
                  : 'Could not reach the sign-in service. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isRegister
                        ? 'Create your AgriLens account'
                        : 'Welcome to AgriLens',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const Gap(AppConstants.gapSmall),
                  Text(
                    widget.isRegister
                        ? 'Create an account to use diagnosis and chat.'
                        : 'Sign in to diagnose a leaf and continue your conversations.',
                  ),
                  const Gap(AppConstants.gapMedium),

                  CustomTextfield(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    labelText: 'Email',
                    autofillHints: const [AutofillHints.email],
                    validator:
                        (value) =>
                            value == null || !value.contains('@')
                                ? 'Enter a valid email address.'
                                : null,
                  ),
                  const Gap(AppConstants.gapSmall),

                  CustomTextfield(
                    controller: _passwordController,
                    obscureText: true,
                    labelText: 'Password',
                    autofillHints: [
                      widget.isRegister
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    validator:
                        (value) =>
                            value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const Gap(AppConstants.gapSmall),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const Gap(AppConstants.gapMedium),
                 
                  CustomFilledButton(
                    btnLabel: widget.isRegister ? 'Create account' : 'Sign in',
                    onTap: () {
                      _submit();
                    },
                    isLoading: _busy,
                  ),
                  const Gap(AppConstants.gapSmall),
                  TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () => context.go(
                              widget.isRegister ? '/login' : '/register',
                            ),
                    child: Text(
                      widget.isRegister
                          ? 'Already have an account? Sign in'
                          : 'New to AgriLens? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
