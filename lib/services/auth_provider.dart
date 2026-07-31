import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// Autenticação real via Firebase Authentication (email/senha + Google),
/// substituindo o login simulado em SharedPreferences. Mantém a mesma API
/// pública (user / isLoading / isLoggedIn / login / signup / loginWithGoogle /
/// logout) usada pelas páginas.
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

      // Mobile/desktop: google_sign_in 7.x.
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
