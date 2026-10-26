import 'package:agrilens/app/auth/services/auth_service.dart';
import 'package:agrilens/app/weather/services/weather_location_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:flutter/material.dart';
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
                  const SizedBox(height: 8),
                  Text(
                    widget.isRegister
                        ? 'Create an account to use diagnosis and chat.'
                        : 'Sign in to diagnose a leaf and continue your conversations.',
                  ),
                  const SizedBox(height: 24),
                  // Card(
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(14),
                  //     child: Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         Text(
                  //           'Local weather',
                  //           style: theme.textTheme.titleSmall,
                  //         ),
                  //         const SizedBox(height: 4),
                  //         const Text(
                  //           'Share your approximate location to get weather for your area. Coordinates are sent with weather requests to AgriLens. You can skip this and allow it later.',
                  //         ),
                  //         const SizedBox(height: 8),
                  //         Align(
                  //           alignment: Alignment.centerRight,
                  //           child: TextButton.icon(
                  //             onPressed:
                  //                 _requestingLocation
                  //                     ? null
                  //                     : _enableWeatherLocation,
                  //             icon:
                  //                 _requestingLocation
                  //                     ? const SizedBox.square(
                  //                       dimension: 16,
                  //                       child: CircularProgressIndicator(
                  //                         strokeWidth: 2,
                  //                       ),
                  //                     )
                  //                     : const Icon(Icons.my_location),
                  //             label: Text(
                  //               _requestingLocation
                  //                   ? 'Getting location…'
                  //                   : 'Allow location',
                  //             ),
                  //           ),
                  //         ),
                  //         if (_locationMessage != null)
                  //           Text(
                  //             _locationMessage!,
                  //             style: theme.textTheme.bodySmall,
                  //           ),
                  //         if (_locationSettingsRequired)
                  //           Align(
                  //             alignment: Alignment.centerRight,
                  //             child: TextButton(
                  //               onPressed:
                  //                   widget
                  //                       .weatherLocationService
                  //                       .openAppSettings,
                  //               child: const Text('Open app settings'),
                  //             ),
                  //           ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator:
                        (value) =>
                            value == null || !value.contains('@')
                                ? 'Enter a valid email address.'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: [
                      widget.isRegister
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator:
                        (value) =>
                            value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child:
                        _busy
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Text(
                              widget.isRegister ? 'Create account' : 'Sign in',
                            ),
                  ),
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
