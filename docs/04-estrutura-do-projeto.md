# 04 — Estrutura do Projeto

## Organização das pastas

```
motogest/
├── lib/                          # Código-fonte Dart do app
│   ├── main.dart                  # Bootstrap, providers, roteamento por estado de login
│   ├── firebase_options.dart      # Config do Firebase (gerada por flutterfire configure)
│   ├── models/
│   │   └── models.dart            # Todas as entidades de domínio (ver 05-banco-de-dados.md)
│   ├── services/
│   │   ├── auth_provider.dart     # Autenticação (Firebase Auth)
│   │   ├── data_provider.dart     # Estado + persistência em tempo real (Firestore)
│   │   └── local_store.dart       # Wrapper sobre shared_preferences
│   ├── theme/
│   │   └── app_theme.dart         # Paleta de cores e ThemeData
│   ├── utils/
│   │   └── input_formatters.dart  # Máscaras de CPF, telefone e moeda
│   ├── widgets/
│   │   ├── app_shell.dart         # Barra de navegação superior (TopMenuBar)
│   │   └── common.dart            # Badge, StatCard, PageHeader, diálogo padrão, PistonIcon
│   └── pages/
│       ├── login_page.dart
│       ├── verify_email_page.dart
│       ├── home_page.dart
│       ├── parts_management_page.dart
│       ├── service_orders_page.dart
│       ├── employees_page.dart
│       ├── search_parts_page.dart
│       └── finances_page.dart
├── test/                          # Testes unitários e de widget (ver 11-testes.md)
│   ├── input_formatters_test.dart
│   └── widget_test.dart
├── assets/icon/                   # Ícones-fonte para o flutter_launcher_icons
├── windows/installer/motogest.iss # Script do Inno Setup (instalador Windows)
├── android/ ios/ linux/ macos/ web/ windows/  # Projetos nativos por plataforma (gerados pelo Flutter)
├── .github/workflows/
│   ├── ci.yml                     # Format + analyze + test em todo push/PR para main
│   └── release-build.yml          # Build Windows/Web + GitHub Release em tags v*.*.*
├── docs/                          # Esta documentação
├── firestore.rules                # Regras de segurança do Firestore
├── firestore.indexes.json         # Índices compostos (atualmente vazio)
├── firebase.json                  # Configuração do projeto Firebase/FlutterFire
├── analysis_options.yaml          # Regras de lint (flutter_lints)
└── pubspec.yaml                   # Dependências e metadados do pacote
```

## Responsabilidade de cada módulo

### `lib/models/`

Camada de dados pura: classes imutáveis (`const` constructors) representando
cada entidade persistida no Firestore, cada uma com `fromJson`/`toJson`
simétricos. Não contêm lógica de negócio — apenas (des)serialização e, em
alguns casos, valores default (ex.: `emailVerified = false`).

### `lib/services/`

Camada de estado e integração com serviços externos:

- **`auth_provider.dart`**: única porta de entrada para operações de
  autenticação. Traduz exceções do Firebase para mensagens em PT-BR e expõe
  um modelo de usuário próprio (`User`, em `models.dart`) em vez de vazar o
  tipo `firebase_auth.User` para a UI.
- **`data_provider.dart`**: única porta de entrada para leitura/escrita de
  dados operacionais. É o maior componente de estado do app; qualquer nova
  entidade de domínio deve seguir o mesmo padrão já usado (referência de
  coleção + listener + métodos `add`/`update`/`delete`).
- **`local_store.dart`**: utilitário genérico de persistência local
  (chave/valor e JSON) sobre `shared_preferences`. Não é usado para as
  entidades operacionais (essas vivem só no Firestore) — serve para
  preferências leves de UI.

### `lib/theme/` e `lib/utils/`

Módulos transversais sem estado: `app_theme.dart` centraliza toda cor/estilo
usado nas páginas (nunca usar cores hardcoded fora dele); `input_formatters.dart`
centraliza toda máscara de campo de formulário usada nos diálogos de
cadastro/edição.

### `lib/widgets/`

Componentes de UI reutilizados por mais de uma página:

- **`app_shell.dart`**: casca comum às telas autenticadas — logo, menu de
  navegação entre as 5 abas, avatar/menu do usuário.
- **`common.dart`**: peças pequenas repetidas em quase toda tela
  (`AppBadge`, `StatCard`, `PageHeader`, `PistonIcon`) mais utilitários
  (`formatCurrency`, `formatDate`, `formatDateTime`, `showAppDialog`,
  `runGuarded`).

### `lib/pages/`

Uma tela por arquivo, cada uma um `StatefulWidget` que:

1. Observa o `DataProvider` (`context.watch`) para renderizar a lista/tabela
   atual.
2. Filtra/pesquisa localmente em memória (nenhuma busca é feita no
   Firestore — todas as coleções são carregadas por completo e filtradas no
   cliente).
3. Abre diálogos internos (`_XxxFormDialog`) para criar/editar registros,
   retornando o objeto construído via `Navigator.pop(result)`.
4. Delega a escrita ao `DataProvider` através de `runGuarded`, que trata
   falhas de rede/permissão mostrando um SnackBar de erro.

Algumas páginas exportam widgets internos para reaproveitamento entre telas
(ex.: `parts_management_page.dart` expõe `statsGridShared`,
`actionsBarShared` e `emptyStateShared`, usados por `employees_page.dart`,
`service_orders_page.dart` e `search_parts_page.dart`).

## Principais arquivos

| Arquivo | Por que é importante |
| --- | --- |
| `lib/main.dart` | Ponto único de bootstrap; qualquer novo `ChangeNotifier` global precisa ser registrado aqui. |
| `lib/services/data_provider.dart` | Fonte única de verdade dos dados operacionais; qualquer nova coleção do Firestore deve ser modelada aqui. |
| `lib/models/models.dart` | Contrato de serialização entre o app e o Firestore — mudanças aqui exigem migração de dados existentes (ver [05-banco-de-dados.md](05-banco-de-dados.md)). |
| `firestore.rules` | Único mecanismo de controle de acesso a dados do sistema. |
| `pubspec.yaml` | Nome do pacote (`gmp_gestor`), versão (`1.0.0+1`) e todas as dependências. |
| `.github/workflows/release-build.yml` | Define como o app é empacotado/distribuído (ver [10-deploy.md](10-deploy.md)). |

## Padrões utilizados

- **Provider / ChangeNotifier** para gerenciamento de estado (não usa
  Riverpod, Bloc, GetX ou similares).
- **Repository implícito**: `DataProvider` acumula tanto o papel de
  repositório (acesso a dados) quanto de estado de UI — não há uma camada
  `Repository`/`UseCase` separada.
- **Composição de widgets compartilhados** em vez de herança — páginas
  reaproveitam funções/widgets (`statsGridShared` etc.) em vez de estender
  uma classe base comum.
- **Formulários como diálogos modais** (`AlertDialog` + `Form` +
  `GlobalKey<FormState>`) para todo create/edit, em vez de telas de rota
  dedicadas.
- **IDs client-side**: novos registros usam
  `DateTime.now().millisecondsSinceEpoch.toString()` como id do documento
  Firestore, em vez de deixar o Firestore gerar o id (`.add()`) ou usar
  UUIDs — ver [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md).
- **Nenhum roteador de páginas** (`Navigator` só é usado para diálogos e para
  o `_Root` condicional em `main.dart`); a navegação entre as 5 abas internas
  usa `IndexedStack`/`AnimatedSwitcher` dentro de `HomePage`, preservando
  estado ao trocar de aba.
