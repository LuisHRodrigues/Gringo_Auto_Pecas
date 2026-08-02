# 08 — Segurança

## Autenticação

- Provida integralmente pelo **Firebase Authentication**; o app não
  implementa nem armazena senha, hash ou token por conta própria.
- Métodos habilitados: **email/senha** e **Google**. Ambos precisam ser
  habilitados manualmente no Console Firebase (não é possível via CLI/CI) —
  ver [09-instalacao.md](09-instalacao.md).
- Sessão gerenciada pelo próprio SDK (`authStateChanges()`); não há
  "lembrar-me" configurável, expiração customizada, nem MFA/2FA.
- **Verificação de email é opcional e não bloqueante**: um usuário pode usar
  o sistema normalmente mesmo sem nunca confirmar o email, desde que já
  tenha dispensado a tela de verificação uma vez (`justSignedUp`). Isso é
  uma decisão de produto deliberada (ver
  [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md)), mas significa que
  **o backend não exige `email_verified == true` para nada** — inclusive
  `firestore.rules` não checa esse campo.

## Autorização (o que cada usuário pode fazer)

**Não há controle de acesso baseado em papel (RBAC) no backend.** O modelo é
"oficina única, equipe única": qualquer usuário que tenha uma conta válida
no projeto Firebase pode ler e escrever **todas** as coleções operacionais
(`parts`, `serviceOrders`, `employees`, `stores`, `transactions`,
`categories`), sem distinção entre "dono", "gerente", "mecânico" ou
"atendente".

O campo `role` em `employees` (mecânico/atendente/gerente/caixa) é **apenas
um dado de negócio** — não está vinculado à conta de autenticação do
usuário logado e não altera nenhuma permissão de leitura/escrita. Ou seja: é
inteiramente possível que o usuário autenticado "Ana" (que fez login) nunca
apareça como um `Employee` no sistema, e mesmo assim tenha acesso total.

## Permissões (`firestore.rules`)

```
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }

    match /parts/{id}          { allow read, write: if signedIn(); }
    match /serviceOrders/{id}  { allow read, write: if signedIn(); }
    match /employees/{id}      { allow read, write: if signedIn(); }
    match /stores/{id}         { allow read, write: if signedIn(); }
    match /transactions/{id}   { allow read, write: if signedIn(); }
    match /categories/{id}     { allow read, write: if signedIn(); }
    match /users/{uid} {
      allow read: if signedIn();
      allow write: if signedIn() && request.auth.uid == uid;
    }
  }
}
```

| Coleção | Leitura | Escrita |
| --- | --- | --- |
| `parts`, `serviceOrders`, `employees`, `stores`, `transactions`, `categories` | Qualquer usuário autenticado | Qualquer usuário autenticado |
| `users/{uid}` | Qualquer usuário autenticado (perfis são públicos entre a equipe) | Apenas o próprio dono do `uid` |

Não há validação de **forma** dos dados nas regras (tipo, obrigatoriedade de
campo, tamanho) — apenas de identidade. Um cliente autenticado, mesmo que
malicioso ou com um bug, pode gravar documentos incompletos/malformados em
qualquer uma das seis coleções operacionais.

## Proteção de dados

- **Em trânsito**: toda comunicação com Firebase Authentication e Firestore
  usa TLS, gerenciado pelo SDK (não configurável/desabilitável pela
  aplicação).
- **Em repouso**: gerenciada pela infraestrutura do Google
  Cloud/Firebase — fora do controle direto deste projeto.
- **Dados sensíveis armazenados**: CPF e telefone de funcionários, nome e
  telefone de clientes (em `serviceOrders`), email/nome de usuários. Nenhum
  desses campos é criptografado ou mascarado em repouso além do que o
  Firestore já oferece nativamente — são texto plano no documento.
- **Fotos de OS**: guardadas como base64 dentro do próprio documento (não em
  um serviço de storage com controle de acesso próprio) — herdam as mesmas
  regras de leitura/escrita de `serviceOrders` (ver
  [05-banco-de-dados.md](05-banco-de-dados.md)).
- Não há LGPD/consentimento explícito implementado no app (sem termos de
  uso, política de privacidade ou fluxo de exclusão de conta/dados pelo
  usuário final).

## Gestão de secrets (senhas, tokens e chaves)

| Artefato | Onde vive | Sensibilidade |
| --- | --- | --- |
| `lib/firebase_options.dart` | Versionado no repositório | Contém API keys do Firebase para cada plataforma. **Não é segredo crítico**: chaves de API do Firebase para apps cliente são, por design do próprio Firebase, protegidas por `firestore.rules`/App Check, não por sigilo da chave — mas ainda assim identificam o projeto. |
| `android/app/google-services.json` | Versionado no repositório | Configuração do app Android no Firebase (mesma natureza da chave acima). |
| Senha do usuário | Nunca chega a este código — o app só chama `signInWithEmailAndPassword`/`createUserWithEmailAndPassword`; o Firebase Auth cuida do hashing e armazenamento. | — |
| Certificado de assinatura Windows | Não existe — o build de release usa `signingConfig = signingConfigs.getByName("debug")` também no Android (chave de debug, não uma chave de produção real). | Ver [15-pendencias.md](15-pendencias.md). |
| SHA-1 do app Android (para Google Sign-In) | Gerado localmente via `./gradlew signingReport` e cadastrado manualmente no Console Firebase | Não versionado. |

Não há um cofre de segredos (Vault, AWS Secrets Manager etc.) nem uso de
variáveis de ambiente de CI para segredos de runtime — o workflow de release
(`release-build.yml`) não referencia nenhum secret do GitHub Actions
(`secrets.*`) hoje.

## Logs e auditoria

- **Autoria de dados**: `parts`, `serviceOrders` e `employees` gravam
  `createdBy` (id, nome, email) e `createdAt` no momento da criação — isso
  funciona como uma trilha de auditoria mínima de "quem criou o quê e
  quando". **Não há rastro de quem editou ou excluiu** um registro depois da
  criação (o campo `createdBy` não é atualizado em `updatePart`/
  `updateOrder`/`updateEmployee`, e a exclusão simplesmente remove o
  documento sem deixar tombstone).
- **Sem logs de aplicação**: o app não envia eventos para nenhum serviço de
  observabilidade (Crashlytics, Sentry, Analytics). O único "log" disponível
  é o console de debug do Flutter em desenvolvimento.
- **Logs de infraestrutura**: o Firebase Console oferece logs de uso do
  Firestore/Auth (quotas, erros de regras) — não integrados nem consultados
  por este projeto.

Ver também [12-operacao.md](12-operacao.md) para como isso afeta
monitoramento/incidentes, e [15-pendencias.md](15-pendencias.md) para os
riscos de segurança conhecidos.
