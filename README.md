# GMP Gestor

Sistema de gestão para oficina de motos, feito em **Flutter** com backend em
**Firebase** (Authentication + Cloud Firestore). Controla peças, ordens de
serviço, funcionários e finanças de uma oficina, com dados sincronizados em
tempo real entre todos os usuários logados (modelo de oficina única).

> Este projeto é o porte completo do protótipo Figma Make **"Tela de
> gerenciamento de peças"** (originalmente React + TypeScript +
> Tailwind/shadcn) para Flutter, mantendo as mesmas telas, fluxos e regras de
> negócio.

## Sumário

- [Funcionalidades](#funcionalidades)
- [Stack técnica](#stack-técnica)
- [Arquitetura](#arquitetura)
- [Modelo de dados (Firestore)](#modelo-de-dados-firestore)
- [Como rodar](#como-rodar)
- [Configuração do Firebase](#configuração-do-firebase)
- [Testes](#testes)
- [CI/CD](#cicd)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Observações sobre a conversão](#observações-sobre-a-conversão)

## Funcionalidades

Login/cadastro mais cinco telas principais, todas conectadas em tempo real ao
Firestore:

- **Login / Cadastro** (`login_page.dart`): autenticação real com email e
  senha ou Google, via Firebase Authentication. Após o cadastro, é exibida uma
  tela de confirmação de email (`verify_email_page.dart`) com opção de
  reenviar o email ou continuar sem verificar.
- **Peças** (`parts_management_page.dart`): catálogo de peças com cards de
  estatística (total, estoque baixo, valor em estoque), busca e formulário de
  adicionar/editar/excluir.
- **Ordens de Serviço** (`service_orders_page.dart`): listagem com filtro por
  status (pendente, em andamento, concluída, cancelada), formulário completo
  (cliente, moto, mecânico, peças usadas, mão de obra, upload de até 3 fotos)
  e tela de detalhes.
- **Funcionários** (`employees_page.dart`): listagem com cargo e status,
  cadastro com máscara de CPF e telefone.
- **Busca de Peças** (`search_parts_page.dart`): catálogo com filtros por
  categoria, marca e disponibilidade em estoque.
- **Finanças** (`finances_page.dart`): múltiplas lojas/negócios, seletor de
  mês, gráficos (área, linha, pizza, barra via `fl_chart`), tabela de
  transações, categorias de receita/despesa personalizáveis por loja, e
  sincronização automática das ordens de serviço concluídas como entradas
  financeiras.

## Stack técnica

| Camada          | Tecnologia                                            |
| --------------- | ------------------------------------------------------ |
| UI               | Flutter (Material), localizado em `pt_BR`              |
| Estado           | `provider` (`ChangeNotifier` / `ChangeNotifierProxyProvider`) |
| Autenticação     | Firebase Authentication (email/senha + Google Sign-In) |
| Banco de dados   | Cloud Firestore (listeners em tempo real)               |
| Gráficos         | `fl_chart`                                              |
| Upload de imagem | `image_picker` (fotos das OSs, em base64/data URL)       |
| Persistência local | `shared_preferences` (preferências leves de UI)      |
| Ícone do app     | `flutter_launcher_icons` (gerado a partir de `assets/icon/`) |

Principais dependências (`pubspec.yaml`): `provider`, `firebase_core`,
`firebase_auth`, `cloud_firestore`, `google_sign_in`, `fl_chart`,
`image_picker`, `shared_preferences`, `intl`, `flutter_launcher_icons` (dev).

## Arquitetura

- **`AuthProvider`** (`lib/services/auth_provider.dart`): encapsula o
  Firebase Auth: login, cadastro, login com Google, logout, reenvio/checagem
  de verificação de email. Expõe `user`, `isLoading`, `isLoggedIn`.
- **`DataProvider`** (`lib/services/data_provider.dart`): mantém o estado de
  peças, ordens de serviço, funcionários, lojas, transações e categorias,
  todos sincronizados via `snapshots()` do Firestore. É reiniciado (listeners
  cancelados e recriados) sempre que o usuário autenticado muda, via
  `syncWithAuth`, ligado ao `AuthProvider` por um
  `ChangeNotifierProxyProvider` em `main.dart`.
- **Roteamento por estado de login**: não há um router de páginas; o widget
  `_Root` em `main.dart` decide entre `LoginPage`, `VerifyEmailPage` e
  `HomePage` com base no estado do `AuthProvider` (equivalente às
  `ProtectedRoute`/`PublicRoute` do projeto React original).
- **Navegação entre telas**: `HomePage` usa `IndexedStack` para preservar o
  estado de cada aba ao trocar entre elas.
- **Transações financeiras "sintéticas"**: o `DataProvider` não persiste uma
  transação para cada OS concluída; em vez disso, `transactionsOf()` calcula
  essas entradas em tempo real a partir de `orders`, evitando duplicidade e
  mantendo os dados sempre consistentes com o status da OS.

## Modelo de dados (Firestore)

Coleções (ver `lib/models/models.dart` para os campos completos):

| Coleção         | Descrição                                                        |
| --------------- | ------------------------------------------------------------------ |
| `parts`          | Peças de moto (código, nome, categoria, marca, preço, estoque)     |
| `serviceOrders`  | Ordens de serviço (cliente, moto, mecânico, peças usadas, fotos, status) |
| `employees`      | Funcionários (nome, CPF, cargo, salário, status)                   |
| `stores`         | Lojas/negócios cadastrados no módulo Finanças                       |
| `transactions`   | Lançamentos financeiros reais (tem `storeId`)                       |
| `categories`     | Categorias personalizadas de entrada/saída, por loja                |
| `users`          | Perfil espelhado de cada usuário autenticado                        |

As regras de segurança (`firestore.rules`) permitem leitura/escrita das
coleções operacionais para qualquer usuário autenticado; o documento de
`users/{uid}` só pode ser escrito pelo próprio dono.

O app inicia sem dados de exemplo: as coleções são populadas conforme o uso
(a única exceção é a loja padrão `motogest`, criada automaticamente no
primeiro login, ver `DataProvider._ensureDefaultStore`).

## Como rodar

Pré-requisito: Flutter instalado (canal stable, SDK Dart 3.3+).

```bash
flutter pub get
flutter run
```

Para rodar no navegador:

```bash
flutter run -d chrome
```

Se for a primeira vez no diretório (pastas de plataforma ausentes):

```bash
flutter create .
flutter pub get
flutter run
```

## Configuração do Firebase

O app já está integrado via FlutterFire. Arquivos relevantes:

- `lib/firebase_options.dart`: configuração gerada pelo `flutterfire configure`
- `firestore.rules`: regras de segurança do Firestore
- `firestore.indexes.json`: índices compostos
- `firebase.json`: referencia regras, índices e as configurações do
  `flutterfire configure` (projeto `gringomotopecas-c285e`)

### Passos manuais no Console Firebase

Precisam ser habilitados uma vez em
[console.firebase.google.com](https://console.firebase.google.com/):

1. **Authentication > Sign-in method > Email/senha**: habilitar (obrigatório
   para login/cadastro por email).
2. **Authentication > Sign-in method > Google**: habilitar (opcional, para o
   botão "Google"). No Android, adicione a impressão **SHA-1** do app em
   *Project settings > Your apps > Android* e baixe novamente o
   `google-services.json`. Gere o SHA-1 com:

   ```bash
   cd android && ./gradlew signingReport
   ```

Para reimplantar as regras após editá-las:

```bash
firebase deploy --only firestore:rules
```

## Testes

```bash
flutter test
```

- `test/input_formatters_test.dart`: máscaras/formatadores de entrada (CPF,
  telefone, moeda).
- `test/widget_test.dart`: formatação de moeda e datas (`formatCurrency`,
  `formatDate`, `formatDateTime`).

## CI/CD

Dois workflows em `.github/workflows/`:

- **`ci.yml`**: roda em todo push/PR para `main`, verificando formatação
  (`dart format`), análise estática (`flutter analyze`) e os testes
  (`flutter test`).
- **`release-build.yml`**: dispara apenas quando uma tag `v*.*.*` é enviada
  (ex.: `v1.2.0`). Builda e publica um GitHub Release com:
  - **Windows**: build de release (`flutter build windows`), com as DLLs do
    Visual C++ Redistributable copiadas para o app ficar autocontido, e um
    instalador `gmp-gestor-setup.exe` gerado com **Inno Setup**
    (`windows/installer/motogest.iss`), usando a versão da tag.
  - **Android**: build de release (`flutter build apk`), um único APK
    universal (`gmp-gestor.apk`) — sem AAB nem split por ABI, já que o app
    não é distribuído pela Play Store.
  - **Web**: build de release (`flutter build web`), compactado em
    `gmp-gestor-web.zip`.

## Estrutura do projeto

```
lib/
  main.dart                    → ponto de entrada, providers e roteamento por estado de login
  firebase_options.dart        → configuração do Firebase (gerada pelo FlutterFire)
  models/models.dart           → modelos de dados (Part, ServiceOrder, Employee, Transaction, Store, Category, User)
  services/
    auth_provider.dart         → autenticação via Firebase Auth (email/senha + Google)
    data_provider.dart         → estado e persistência em tempo real no Cloud Firestore
    local_store.dart           → utilidades de persistência local (shared_preferences)
  theme/app_theme.dart         → tema/paleta de cores do app
  utils/input_formatters.dart  → máscaras de CPF, telefone etc.
  widgets/
    app_shell.dart             → barra de navegação superior (TopMenuBar)
    common.dart                → Badge, StatCard, PageHeader, formatadores de moeda/data
  pages/
    login_page.dart            → login e cadastro
    verify_email_page.dart     → confirmação de email pós-cadastro
    home_page.dart             → shell com IndexedStack das abas
    parts_management_page.dart → gestão de peças
    service_orders_page.dart   → ordens de serviço
    employees_page.dart        → funcionários
    search_parts_page.dart     → busca/catálogo de peças
    finances_page.dart         → módulo financeiro (lojas, gráficos, transações)
test/                          → testes unitários e de widget
assets/icon/                   → ícones fonte para o flutter_launcher_icons
windows/installer/motogest.iss → script do Inno Setup usado no release Windows
.github/workflows/             → CI (ci.yml) e build/publish de releases (release-build.yml)
firestore.rules                → regras de segurança do Firestore
firestore.indexes.json         → índices compostos do Firestore
firebase.json                  → configuração do projeto Firebase
android/ ios/ linux/ macos/ windows/ web/  → projetos de cada plataforma (gerados pelo Flutter)
```

## Observações sobre a conversão

- As cores em `oklch` do tema React original foram convertidas para os
  equivalentes RGB mais próximos em `app_theme.dart`.
- A navegação usa `IndexedStack` (estado preservado entre abas), no lugar do
  `react-router`.
- Os gráficos do `recharts` foram reescritos com `fl_chart`.
- O login com Google usa o fluxo real do Firebase/`google_sign_in` (popup na
  web, `GoogleSignIn.authenticate()` em mobile/desktop); não é mais
  simulado.
- O pacote Dart e o binário Windows chamam-se `gmp_gestor` internamente
  (nome do app: **GMP Gestor**); o `applicationId`/namespace Android ainda é
  `com.example.motogest`, herdado do nome original do projeto.
