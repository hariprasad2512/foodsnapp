import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/repositories/auth_repository.dart';
import 'validators.dart';

/// S01 — Sign in. Source of truth: UI spec §6 S01 + microcopy §11.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _email.text.trim();
      final password = _password.text;
      if (_createAccount) {
        await repo.signUpWithEmail(email, password);
      } else {
        await repo.signInWithEmail(email, password);
      }
      // Router redirect handles the rest.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      // Dismissing the account chooser is not an error — just reset.
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Something went wrong. Try again.');
      }
    } on FirebaseAuthException catch (e) {
      // Closing the web popup is a dismissal, not an error.
      if (e.code != 'popup-closed-by-user') {
        setState(() => _error = authErrorMessage(e));
      }
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = looksLikeEmail(_email.text) &&
        _password.text.length >= 6 &&
        !_busy;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fastfood, size: 64),
                const SizedBox(height: 12),
                Text('FoodSnapp',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Snap your meal. Send it. Done.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _submitGoogle,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: canSubmit ? _submitEmail : null,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_createAccount
                                ? 'Create account'
                                : 'Sign in'),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _createAccount = !_createAccount;
                            _error = null;
                          }),
                  child: Text(_createAccount
                      ? 'Have an account? Sign in'
                      : 'New here? Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
