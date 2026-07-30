import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_provider.dart';
import 'services/data_provider.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MotoGestApp());
}

class MotoGestApp extends StatelessWidget {
  const MotoGestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: MaterialApp(
        title: 'MotoGest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _Root(),
      ),
    );
  }
}

/// Equivalente às ProtectedRoute/PublicRoute do routes.tsx.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return auth.isLoggedIn ? const HomePage() : const LoginPage();
  }
}
