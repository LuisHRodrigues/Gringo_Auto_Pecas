import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

/// Exibida sempre que a conta (por email/senha) ainda não confirmou o
/// endereço de email — tanto logo após o cadastro quanto em qualquer login
/// futuro — bloqueando o acesso ao sistema até a confirmação.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _checking = false;
  bool _resending = false;
  Timer? _autoCheck;

  @override
  void initState() {
    super.initState();
    // Confere automaticamente a cada alguns segundos, para liberar o acesso
    // assim que o usuário clicar no link recebido por email, sem precisar
    // apertar manualmente em "Já confirmei".
    _autoCheck =
        Timer.periodic(const Duration(seconds: 5), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _autoCheck?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    await context.read<AuthProvider>().reloadUser();
    if (!mounted) return;
    setState(() => _checking = false);
    final verified = context.read<AuthProvider>().user?.emailVerified ?? false;
    if (!verified && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ainda não encontramos a confirmação. '
            'Verifique sua caixa de entrada (e o spam).'),
      ));
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await context.read<AuthProvider>().sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email de verificação reenviado!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível reenviar agora. Tente novamente '
              'em alguns instantes.'),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text('Confirme seu email',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Enviamos um link de confirmação para $email. '
                  'Abra o email e clique no link para liberar o acesso ao '
                  'sistema.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checking ? null : () => _check(),
                    child: Text(_checking ? 'Verificando...' : 'Já confirmei'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _resending ? null : _resend,
                    child: Text(_resending ? 'Enviando...' : 'Reenviar email'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
