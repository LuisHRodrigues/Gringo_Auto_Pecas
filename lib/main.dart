import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_provider.dart';
import 'services/data_provider.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/verify_email_page.dart';

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
        // O DataProvider reinicia os listeners do Firestore sempre que o
        // usuário autenticado muda (login/logout/troca de conta) — ver
        // syncWithAuth em data_provider.dart.
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, auth, data) =>
              (data ?? DataProvider())..syncWithAuth(auth.user?.id),
        ),
      ],
      child: MaterialApp(
        title: 'MotoGest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
    if (!auth.isLoggedIn) return const LoginPage();
    // A confirmação de email só é exibida logo após criar a conta nesta
    // sessão — não bloqueia logins futuros de contas ainda não verificadas.
    if (auth.justSignedUp && !auth.user!.emailVerified) {
      return const VerifyEmailPage();
    }
    return const HomePage();
  }
}
