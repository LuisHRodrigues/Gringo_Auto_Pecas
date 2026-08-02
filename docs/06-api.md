# 06 — APIs e Integrações

## Não há uma API própria

O GMP Gestor **não expõe nem consome uma API REST/GraphQL própria**. Não
existe servidor de aplicação no projeto. Todo acesso a dados acontece
diretamente do app Flutter para os serviços gerenciados do Firebase, através
dos SDKs oficiais (`cloud_firestore`, `firebase_auth`), que já implementam
por baixo dos panos comunicação em tempo real, cache offline, retry, etc.

Esta seção documenta, portanto, **os pontos de integração real do sistema**:
os métodos do Firebase Auth SDK e as coleções/queries do Firestore SDK
usados como se fossem "endpoints".

## "Endpoints" de autenticação (Firebase Authentication)

Todos acessados via `AuthProvider` (`lib/services/auth_provider.dart`):

| Operação | Método do SDK | Parâmetros | Retorno / Erros |
| --- | --- | --- | --- |
| Login por email/senha | `FirebaseAuth.signInWithEmailAndPassword` | `email`, `password` | Lança `Exception` com mensagem em PT-BR traduzida de `FirebaseAuthException` (ver tabela abaixo). |
| Cadastro por email/senha | `FirebaseAuth.createUserWithEmailAndPassword` + `updateDisplayName` + `sendEmailVerification` | `email`, `password`, `name` | Marca `justSignedUp = true`; grava perfil em `users/{uid}`. |
| Login/cadastro Google (web) | `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` | — | Usa o popup nativo do Firebase; grava perfil em `users/{uid}`. |
| Login/cadastro Google (mobile/desktop) | `GoogleSignIn.instance.authenticate()` → `FirebaseAuth.signInWithCredential` | — | Requer SHA-1 cadastrado no Android; lança erro se `idToken` vier nulo. |
| Reenvio de verificação | `User.sendEmailVerification` | — | — |
| Checagem de verificação | `User.reload()` + leitura de `emailVerified` | — | Chamado a cada 5s enquanto a tela de verificação está aberta. |
| Logout | `GoogleSignIn.instance.signOut()` (não-web) + `FirebaseAuth.signOut()` | — | — |

### Autenticação

- **Mecanismo**: Firebase Authentication (tokens JWT gerenciados
  internamente pelo SDK; o app nunca manipula o token diretamente).
- **Sessão**: mantida pelo próprio SDK (`authStateChanges()` stream),
  observada pelo `AuthProvider` no construtor.
- **Nenhum backend intermediário** valida ou emite tokens — o Firestore
  confia diretamente no `request.auth` que o Firebase injeta a partir do
  token do cliente.

### Erros e mensagens (tradução PT-BR)

| Código Firebase | Mensagem exibida |
| --- | --- |
| `invalid-credential`, `wrong-password`, `user-not-found` | "Email ou senha incorretos" |
| `invalid-email` | "Email inválido" |
| `user-disabled` | "Esta conta foi desativada" |
| `email-already-in-use` | "Este email já está cadastrado" |
| `weak-password` | "A senha precisa ter no mínimo 6 caracteres" |
| `too-many-requests` | "Muitas tentativas. Tente novamente mais tarde" |
| `network-request-failed` | "Sem conexão com a internet" |
| `operation-not-allowed` | "Método de login não habilitado no Firebase" |
| (outros) | `e.message` bruto do Firebase |

## "Endpoints" de dados (Cloud Firestore)

Todos acessados via `DataProvider` (`lib/services/data_provider.dart`). Não
há paginação, filtros server-side, nem ordenação — cada coleção é lida por
inteiro via um listener e filtrada/ordenada em memória no cliente.

| Coleção | Operações expostas | Query usada |
| --- | --- | --- |
| `parts` | listen, `addPart`, `updatePart` (mesmo método, `set`), `deletePart` | `collection('parts').snapshots()` (sem filtro) |
| `serviceOrders` | listen, `addOrder`, `updateOrder`, `deleteOrder` | `collection('serviceOrders').snapshots()` (sem filtro) |
| `employees` | listen, `addEmployee`, `updateEmployee`, `deleteEmployee` | `collection('employees').snapshots()` (sem filtro) |
| `stores` | listen, `addStore`, `deleteStore` (+ batch de limpeza) | `collection('stores').snapshots()` (sem filtro) |
| `transactions` | listen, `addTransaction` | `collection('transactions').snapshots()` (sem filtro); filtro por `storeId` só em `deleteStore`/`renameCategory` (`where('storeId', isEqualTo: id)`) |
| `categories` | listen, `addCategory`, `deleteCategory`, `renameCategory` | `collection('categories').snapshots()` (sem filtro) |
| `users` | escrita apenas (`_saveUserProfile` em `AuthProvider`) | `collection('users').doc(uid).set(..., merge: true)` |

### Parâmetros e formato de payload

Toda escrita usa `toJson()` do modelo correspondente (ver
[05-banco-de-dados.md](05-banco-de-dados.md) para os campos de cada
entidade). Exemplo — criar uma peça:

```dart
// lib/services/data_provider.dart
Future<void> addPart(MotorcyclePart part) =>
    _partsRef.doc(part.id).set(part.toJson());
```

```json
// payload gravado em parts/{id}
{
  "id": "1732999999999",
  "code": "MT-001",
  "name": "Pastilha de Freio Dianteira",
  "category": "Freios",
  "brand": "Honda",
  "price": 89.9,
  "stock": 12,
  "description": null,
  "barcode": null,
  "createdBy": { "id": "uid123", "name": "Ana", "email": "ana@ex.com" },
  "createdAt": "2026-08-02T14:00:00.000"
}
```

### Respostas e erros

O SDK do Firestore não retorna "respostas" no sentido HTTP — `set()`/
`delete()` retornam um `Future<void>` que completa ou lança exceção (ex.:
`FirebaseException` com `code: 'permission-denied'` se as regras negarem o
acesso, ou erro de rede se o dispositivo estiver offline sem cache local
aplicável). Todas as escritas feitas a partir da UI passam por
`runGuarded()` (`lib/widgets/common.dart`), que:

1. Executa a ação (`await action()`).
2. Em caso de sucesso, retorna `true` (a página decide se mostra um toast de
   sucesso).
3. Em caso de exceção, mostra um `SnackBar` genérico ("Não foi possível
   salvar. Verifique sua conexão e tente novamente.") e retorna `false`.

Não há tratamento diferenciado por tipo de erro (ex.: distinguir
"permission-denied" de "unavailable") — toda falha cai na mesma mensagem
genérica.

## Integrações com sistemas externos

| Sistema | Tipo de integração | Observação |
| --- | --- | --- |
| Firebase Authentication | SDK cliente (`firebase_auth`) | Ver seção de autenticação acima. |
| Cloud Firestore | SDK cliente (`cloud_firestore`) | Ver seção de dados acima. |
| Google Sign-In | SDK cliente (`google_sign_in` no mobile/desktop; popup nativo do Firebase na web) | Apenas para obter a credencial Google usada no login do Firebase Auth — não é uma integração de dados (não lê Contacts, Drive etc.). |
| GitHub Actions / GitHub Releases | CI/CD | Não é uma integração em runtime do app — usada apenas para build e distribuição (ver [10-deploy.md](10-deploy.md)). |

Não há integrações com gateways de pagamento, sistemas fiscais, serviços de
notificação push (FCM não está configurado), serviços de e-mail transacional
próprios (o email de verificação é enviado pelo próprio Firebase
Authentication) ou qualquer webhook.
