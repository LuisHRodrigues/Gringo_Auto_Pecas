import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';


class _GoogleDesktopOAuth {
  static String get clientId => dotenv.get('GOOGLE_OAUTH_CLIENT_ID');
  static String get clientSecret => dotenv.get('GOOGLE_OAUTH_CLIENT_SECRET');
  static const redirectPort = 48871;
  static String get redirectUri => 'http://localhost:$redirectPort';
}


class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // O estado começa carregando até o Firebase emitir o primeiro evento.
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = true;
  // Marca que a conta acabou de ser criada nesta sessão do app — usado só
  // para decidir se mostramos a tela de "confirme seu email" uma única vez,
  // logo após o cadastro. Não deve bloquear logins futuros.
  bool _justSignedUp = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get justSignedUp => _justSignedUp;

  /// Fecha a tela de confirmação de email (usuário optou por continuar sem
  /// verificar agora, ou já confirmou).
  void dismissJustSignedUp() {
    if (!_justSignedUp) return;
    _justSignedUp = false;
    notifyListeners();
  }

  void _onAuthStateChanged(fb.User? fbUser) {
    _user = fbUser == null ? null : _mapUser(fbUser);
    _isLoading = false;
    notifyListeners();
  }

  User _mapUser(fb.User u) {
    final isGoogle = u.providerData.any((p) => p.providerId == 'google.com');
    return User(
      id: u.uid,
      email: u.email ?? '',
      name: (u.displayName?.trim().isNotEmpty ?? false)
          ? u.displayName!
          : (u.email?.split('@').first ?? 'Usuário'),
      // photoURL pode vir como string vazia (não nula) — normaliza para null
      // para não criar um NetworkImage('') inválido.
      avatar: (u.photoURL?.isNotEmpty ?? false) ? u.photoURL : null,
      provider: isGoogle ? 'google' : 'email',
      // Contas Google já vêm com o email verificado pelo próprio provedor.
      emailVerified: isGoogle || u.emailVerified,
    );
  }

  /// Reenvia o email de verificação para o usuário logado atualmente.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recarrega o usuário atual do Firebase (ex.: para checar se ele já
  /// confirmou o email em outra aba/dispositivo) e atualiza o estado local.
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null) {
      _user = _mapUser(refreshed);
      notifyListeners();
    }
  }

  /// Lança [Exception] com mensagem em português, como no original.
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_messageFor(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_messageFor(e));
    }
  }

  Future<void> signup(String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(name);
      await cred.user?.sendEmailVerification();
      await cred.user?.reload();
      _justSignedUp = true;
      // Atualiza imediatamente o estado local com o nome (o reload acima nem
      // sempre dispara um novo evento de authStateChanges).
      final refreshed = _auth.currentUser;
      if (refreshed != null) {
        _user = _mapUser(refreshed);
        notifyListeners();
      }
      await _saveUserProfile(cred.user, name: name);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_messageFor(e));
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      if (kIsWeb) {
        // Na web o fluxo nativo do google_sign_in não se aplica: usamos o
        // popup do próprio Firebase Auth.
        final provider = fb.GoogleAuthProvider();
        final cred = await _auth.signInWithPopup(provider);
        await _saveUserProfile(cred.user);
        return;
      }

      // O pacote google_sign_in não tem implementação para Windows/Linux
      // (só Android, iOS, macOS, Web) — nesses dois, o fluxo OAuth via
      // navegador do sistema é usado no lugar.
      if (Platform.isWindows || Platform.isLinux) {
        await _loginWithGoogleDesktop();
        return;
      }

      // Android/iOS/macOS: google_sign_in 7.x.
      final google = GoogleSignIn.instance;
      await google.initialize();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Não foi possível obter as credenciais do Google. '
            'Verifique se o provedor Google está habilitado no Firebase '
            'e se o SHA-1 do app foi adicionado.');
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final cred = await _auth.signInWithCredential(credential);
      await _saveUserProfile(cred.user);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_messageFor(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Login com Google cancelado');
      }
      throw Exception('Erro ao fazer login com Google: ${e.description}');
    }
  }

  /// Login com Google no Windows/Linux via fluxo OAuth "loopback": abre o
  /// navegador padrão do sistema, um servidor HTTP local temporário
  /// (127.0.0.1) recebe o redirect com o código de autorização, e trocamos
  /// esse código pelos tokens diretamente com o endpoint do Google.
  Future<void> _loginWithGoogleDesktop() async {
    final code = await _authorizationCodeViaLoopback();
    if (code == null) {
      throw Exception('Login com Google cancelado');
    }

    final tokenResponse = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'client_id': _GoogleDesktopOAuth.clientId,
        'client_secret': _GoogleDesktopOAuth.clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': _GoogleDesktopOAuth.redirectUri,
      },
    );
    final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final idToken = tokenJson['id_token'] as String?;
    if (tokenResponse.statusCode != 200 || idToken == null) {
      throw Exception('Não foi possível obter as credenciais do Google '
          '(${tokenJson['error_description'] ?? tokenJson['error'] ?? tokenResponse.statusCode}).');
    }

    final credential = fb.GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: tokenJson['access_token'] as String?,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _saveUserProfile(cred.user);
  }

  /// Sobe um `HttpServer` em 127.0.0.1 na porta configurada, abre o
  /// navegador padrão do sistema na tela de login do Google, e aguarda o
  /// redirect de volta com o `code` de autorização (ou `null` se o usuário
  /// cancelar, a porta já estiver em uso, ou nada chegar dentro do timeout).
  Future<String?> _authorizationCodeViaLoopback() async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _GoogleDesktopOAuth.redirectPort,
      );
    } catch (_) {
      throw Exception('Não foi possível iniciar o login com Google: a porta '
          '${_GoogleDesktopOAuth.redirectPort} já está em uso nesta '
          'máquina. Feche o programa que a estiver usando e tente de novo.');
    }

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'response_type': 'code',
      'client_id': _GoogleDesktopOAuth.clientId,
      'redirect_uri': _GoogleDesktopOAuth.redirectUri,
      'scope': 'openid email profile',
      // Garante um refresh_token e a tela de consentimento sempre que
      // necessário (evita ficar preso em uma sessão do Google já expirada).
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    try {
      final launched =
          await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Não foi possível abrir o navegador do sistema.');
      }

      final request = await server.first.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw Exception('Login com Google expirou'),
      );

      const html = '<!DOCTYPE html><html><head><meta charset="utf-8">'
          '<title>GMP Gestor</title></head><body '
          'style="font-family: sans-serif; text-align: center; '
          'padding-top: 80px;"><h2>Login concluído.</h2>'
          '<p>Pode fechar esta aba e voltar para o GMP Gestor.</p>'
          '</body></html>';
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(html);
      await request.response.close();

      return request.uri.queryParameters['code'];
    } finally {
      await server.close(force: true);
    }
  }

  Future<void> logout() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Ignora falhas ao desconectar do Google (ex.: nunca logou por ele).
    }
    _justSignedUp = false;
    await _auth.signOut();
  }

  /// Mantém um documento `users/{uid}` espelhando o perfil — útil para
  /// listar/identificar quem mexeu no sistema.
  Future<void> _saveUserProfile(fb.User? u, {String? name}) async {
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set({
      'id': u.uid,
      'email': u.email,
      'name': name ?? u.displayName ?? u.email?.split('@').first,
      'avatar': u.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _messageFor(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email ou senha incorretos';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-disabled':
        return 'Esta conta foi desativada';
      case 'email-already-in-use':
        return 'Este email já está cadastrado';
      case 'weak-password':
        return 'A senha precisa ter no mínimo 6 caracteres';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      case 'network-request-failed':
        return 'Sem conexão com a internet';
      case 'operation-not-allowed':
        return 'Método de login não habilitado no Firebase';
      default:
        return e.message ?? 'Erro de autenticação';
    }
  }
}
