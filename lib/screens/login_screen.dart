import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'admin@gmail.com');
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim().toLowerCase();
    if (email != 'admin@gmail.com') {
      setState(() => _error = 'This account is not authorized to access SM mart Admin.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _password.text,
      );
      if (result.user?.email?.trim().toLowerCase() != 'admin@gmail.com') {
        await Supabase.instance.client.auth.signOut();
        throw const AuthException('Admin access only.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFE8F1E9),
                        child: Icon(Icons.eco_rounded, color: SmMartAdminApp.brandGreen, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text('SM mart', textAlign: TextAlign.center, style: TextStyle(color: SmMartAdminApp.brandGreen, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      const Text('Admin sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Sign in with the existing store administrator account.', textAlign: TextAlign.center),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        onSubmitted: (_) => _busy ? null : _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Restricted to the existing authorized admin account.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
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
