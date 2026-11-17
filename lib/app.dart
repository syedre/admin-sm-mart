import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';

class SmMartAdminApp extends StatelessWidget {
  const SmMartAdminApp({super.key});

  static const brandGreen = Color(0xFF246B45);
  static const pageBackground = Color(0xFFFAF8F3);

  @override
  Widget build(BuildContext context) {
    final configured = Supabase.instance.isInitialized;
    return MaterialApp(
      title: 'SM mart Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandGreen,
          primary: brandGreen,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBackground,
          foregroundColor: Color(0xFF17231B),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9E7E0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
          ),
        ),
      ),
      home: !configured
          ? const _ConfigurationScreen()
          : StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = Supabase.instance.client.auth.currentSession;
                final email = Supabase.instance.client.auth.currentUser?.email
                    ?.trim()
                    .toLowerCase();
                if (session != null && email == 'admin@gmail.com') {
                  return const AdminShell();
                }
                if (session != null && email != 'admin@gmail.com') {
                  Supabase.instance.client.auth.signOut();
                }
                return const LoginScreen();
              },
            ),
    );
  }
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 52, color: SmMartAdminApp.brandGreen),
                  SizedBox(height: 18),
                  Text('Configure SM mart Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(
                    'Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using --dart-define. Only the public publishable key is allowed in the mobile app.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
