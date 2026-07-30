# MotoGest — versão Flutter

Porte completo do projeto Figma Make **"Tela de gerenciamento de peças"** (originalmente React + TypeScript + Tailwind/shadcn) para **Flutter**, mantendo as mesmas telas, fluxos e dados de exemplo.

## O que está incluído

Cinco telas mais a tela de login, equivalentes uma a uma ao original:

- **Login / Cadastro** com **Firebase Authentication** real (email/senha + Google)
- **Peças** — listagem, busca, cards de estatística, adicionar/editar/excluir
- **Ordens de Serviço** — listagem, formulário com upload de até 3 fotos, tela de detalhes
- **Funcionários** — listagem com cargos e status, formulário com máscara de CPF
- **Busca de Peças** — catálogo com filtros (categoria, marca, disponibilidade)
- **Finanças** — múltiplas lojas, seletor de mês, gráficos (área, linha, pizza, barra via `fl_chart`), tabela de transações e sincronização automática das OSs concluídas como entradas

Os dados são sincronizados em **tempo real** com o **Cloud Firestore** (projeto Firebase `gringomotopecas-c285e`), compartilhados entre todos os usuários logados (modelo de oficina única).

## Firebase

O app está integrado ao Firebase via FlutterFire. Arquivos relevantes:

- `lib/firebase_options.dart` — configuração gerada pelo `flutterfire configure`
- `firestore.rules` — regras de segurança (qualquer usuário autenticado lê/escreve as coleções operacionais)
- `firebase.json` — referencia as regras e índices do Firestore

Coleções no Firestore: `parts`, `serviceOrders`, `employees`, `stores`,
`transactions` (com campo `storeId`) e `users` (perfil de cada usuário).

### Passos manuais necessários no Console Firebase

Estes não podem ser feitos por CLI e precisam ser habilitados uma vez em
[console.firebase.google.com](https://console.firebase.google.com/project/gringomotopecas-c285e/authentication/providers):

1. **Authentication → Sign-in method → Email/senha**: habilitar. (Obrigatório
   para login/cadastro por email funcionarem.)
2. **Authentication → Sign-in method → Google**: habilitar (opcional, para o
   botão "Google"). No Android, adicione também a impressão **SHA-1** do app em
   *Project settings → Your apps → Android* e baixe novamente o
   `google-services.json`. Gere o SHA-1 com:
   ```bash
   cd android && ./gradlew signingReport
   ```

Para reimplantar as regras após editá-las:

```bash
firebase deploy --only firestore:rules --project gringomotopecas-c285e
```

## Como rodar

Pré-requisito: ter o Flutter instalado (canal stable, SDK Dart 3.3+).

```bash
flutter pub get
flutter run
```

Para rodar no navegador:

```bash
flutter run -d chrome
```

Se for a primeira vez no diretório, gere as pastas de plataforma:

```bash
flutter create .
flutter pub get
flutter run
```

## Estrutura

```
lib/
  main.dart                  → ponto de entrada, providers e roteamento por estado de login
  models/models.dart         → modelos (Part, ServiceOrder, Employee, Transaction, etc.)
  data/                      → dados de exemplo (mesmo conteúdo dos sample-*.ts)
  firebase_options.dart      → configuração do Firebase (gerada pelo FlutterFire)
  services/
    auth_provider.dart       → autenticação via Firebase Auth (email/senha + Google)
    data_provider.dart       → estado e persistência em tempo real no Cloud Firestore
  theme/app_theme.dart       → paleta convertida do theme.css
  widgets/
    app_shell.dart           → barra de navegação superior (TopMenuBar)
    common.dart              → Badge, StatCard, PageHeader, ícone do pistão, formatadores
  pages/                     → as seis telas
```

## Observações sobre a conversão

- As cores em `oklch` do tema original foram convertidas para os equivalentes RGB mais próximos.
- O login com Google é simulado, exatamente como no projeto original (não há OAuth real).
- A navegação usa `IndexedStack` (estado preservado entre abas), no lugar do `react-router`.
- Os gráficos do `recharts` foram reescritos com `fl_chart`.
