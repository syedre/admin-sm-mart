import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var configured = false;

  try {
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseKey =
        dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
      );
      configured = true;
    }
  } catch (error) {
    debugPrint('SM mart Admin configuration could not be loaded: $error');
  }

  runApp(SmMartAdminApp(configured: configured));
}
