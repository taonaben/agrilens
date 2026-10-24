import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  final bool supabaseReady;

  const AuthPage({super.key, required this.supabaseReady});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_creatingAccount) {
        final result = await auth.signUp(email: email, password: password);
        if (result.session == null) {
          _notice = 'Check your email to confirm your account, then sign in.';
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      _error = error.message;
    } catch (_) {
      _error =
          'Could not reach the sign-in service. Check your connection and retry.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                widget.supabaseReady
                    ? _buildForm(theme)
                    : _buildConfigurationMessage(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationMessage(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect AgriLens', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          'Add SUPABASE_URL and SUPABASE_ANON_KEY to the app .env file, then '
          'configure AGRILENS_API_BASE_URL for the FastAPI service.',
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _creatingAccount
                ? 'Create your AgriLens account'
                : 'Welcome to AgriLens',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _creatingAccount
                ? 'Your sign-in protects requests to the AgriLens service.'
                : 'Sign in to diagnose a leaf and continue your conversations.',
          ),
          const SizedBox(height: 24),
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
              _creatingAccount
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ],
            decoration: const InputDecoration(labelText: 'Password'),
            validator:
                (value) =>
                    value == null || value.length < 8
                        ? 'Use at least 8 characters.'
                        : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!, style: TextStyle(color: theme.colorScheme.primary)),
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
                    : Text(_creatingAccount ? 'Create account' : 'Sign in'),
          ),
          TextButton(
            onPressed:
                _busy
                    ? null
                    : () => setState(() {
                      _creatingAccount = !_creatingAccount;
                      _error = null;
                      _notice = null;
                    }),
            child: Text(
              _creatingAccount
                  ? 'Already have an account? Sign in'
                  : 'New to AgriLens? Create an account',
            ),
          ),
        ],
      ),
    );
  }
}
