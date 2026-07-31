import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _loading = false;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _signName = TextEditingController();
  final _signEmail = TextEditingController();
  final _signPass = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _signName.dispose();
    _signEmail.dispose();
    _signPass.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.destructive : AppColors.primary,
      ));
  }

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    try {
      await context
          .read<AuthProvider>()
          .login(_loginEmail.text.trim(), _loginPass.text);
      _toast('Login realizado com sucesso!');
    } catch (e) {
      _toast(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static final _emailRegex =
      RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$');

  Future<void> _doSignup() async {
    if (_signName.text.trim().isEmpty) {
      _toast('Informe seu nome', error: true);
      return;
    }
    if (!_emailRegex.hasMatch(_signEmail.text.trim())) {
      _toast('Informe um email válido', error: true);
      return;
    }
    if (_signPass.text.length < 6) {
      _toast('Mínimo de 6 caracteres', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signup(
            _signEmail.text.trim(),
            _signPass.text,
            _signName.text.trim(),
          );
      _toast('Conta criada! Enviamos um email de confirmação — '
          'verifique sua caixa de entrada.');
    } catch (e) {
      _toast(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doGoogle() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().loginWithGoogle();
      _toast('Login com Google realizado!');
    } catch (_) {
      _toast('Erro ao fazer login com Google', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _msg(Object e) =>
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabeçalho com ícone de moto
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.two_wheeler,
                      size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text('Gerenciamento de Peças',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Faça login para gerenciar seu estoque',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground)),
                const SizedBox(height: 32),

                // Cartão
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Bem-vindo',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Entre com sua conta ou crie uma nova',
                          style: TextStyle(color: AppColors.mutedForeground)),
                      const SizedBox(height: 20),

                      // Abas
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: TabBar(
                          controller: _tab,
                          indicator: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: AppColors.foreground,
                          unselectedLabelColor: AppColors.mutedForeground,
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Cadastro'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _loginTab(),
                            _signupTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Seus dados são sincronizados com segurança na nuvem (Firebase)',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    TextInputType? type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _loginTab() {
    return Column(
      children: [
        _field(
            controller: _loginEmail,
            label: 'Email',
            icon: Icons.mail_outline,
            hint: 'seu@email.com',
            type: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _field(
            controller: _loginPass,
            label: 'Senha',
            icon: Icons.lock_outline,
            hint: '••••••••',
            obscure: true),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _doLogin,
            child: Text(_loading ? 'Entrando...' : 'Entrar'),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: const [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('OU CONTINUE COM',
                style:
                    TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _doGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 24),
            label: const Text('Google'),
          ),
        ),
      ],
    );
  }

  Widget _signupTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _field(
              controller: _signName,
              label: 'Nome completo',
              icon: Icons.person_outline,
              hint: 'Seu nome'),
          const SizedBox(height: 16),
          _field(
              controller: _signEmail,
              label: 'Email',
              icon: Icons.mail_outline,
              hint: 'seu@email.com',
              type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _field(
              controller: _signPass,
              label: 'Senha',
              icon: Icons.lock_outline,
              hint: '••••••••',
              obscure: true),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Mínimo de 6 caracteres',
                style:
                    TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _doSignup,
              child: Text(_loading ? 'Criando conta...' : 'Criar conta'),
            ),
          ),
        ],
      ),
    );
  }
}
