# 14 — Changelog

Reconstruído a partir do histórico de commits em `main` (não há um
`CHANGELOG.md` mantido manualmente até esta documentação). Versão do
pacote hoje: **1.0.0+1** (`pubspec.yaml`) — o projeto ainda não passou por
um bump formal de versão acompanhando essas mudanças.

## 2026-08-02

- **`09feb8b`** — docs: adicionada seção de CI/CD ao `README.md`, descrevendo
  os workflows de teste e build/release.
- **`72e8128`** — fix: ajuste dos limites e títulos dos eixos dos gráficos
  financeiros, para marcações "redondas" no eixo Y (`_niceAxisBounds` em
  `finances_page.dart`).
- **`597b944`** — chore: atualização dos ícones do app e arquivos de
  manifesto em todas as plataformas (introdução do `flutter_launcher_icons`
  e de `assets/icon/`).
- **`bcbe096`** — feat: renomeação do projeto de "MotoGest" para
  **"GMP Gestor"** (`pubspec.yaml`, nome exibido no `AppShell`, binário
  Windows) — identificadores nativos (Android/iOS namespace) mantidos como
  legado (ver [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md)).
- **`f51dcef`** — feat: adicionado o script do Inno Setup
  (`windows/installer/motogest.iss`) para gerar o instalador Windows.
- **`2ec776c`** — feat: adicionada a geração do instalador `.exe` via Inno
  Setup ao workflow `release-build.yml`.
- **`75df9ac`** — feat: remoção dos arquivos de dados de exemplo
  (`lib/data/sample_orders_finance.dart`,
  `lib/data/sample_parts_employees.dart`) — o app passou a iniciar sem dados
  fictícios pré-carregados.
- **`e4b843e`** — docs: atualização do `README.md` para esclarecer
  funcionalidades do projeto.

## 2026-07-31

- **`e9c7cdb`** — feat: ajuste do fluxo de verificação de email para
  **permitir acesso continuado** de usuários que não confirmaram o email
  (a verificação deixou de ser bloqueante em logins futuros).
- **`8c1a3c0`** — feat: adicionado o campo de verificação de email ao
  modelo de usuário e implementado o fluxo de verificação
  (`VerifyEmailPage`, `AuthProvider.justSignedUp`/`sendEmailVerification`/
  `reloadUser`).

## 2026-07-30

- **`31b3376`** — chore: aprimoramento do workflow de release build —
  validação de `GOOGLE_SERVICES_JSON` e remoção dos jobs de build
  iOS/macOS (o pipeline de release ficou restrito a Windows e Web).

## 2026-07-29

- **`4a34401`** — **First commit**: importação inicial do projeto (porte do
  protótipo Figma Make "Tela de gerenciamento de peças" para Flutter, já com
  Firebase Authentication + Cloud Firestore integrados, as 5 telas
  principais + login, tema, formatadores e dados de exemplo).

---

*Para o motivo por trás de cada decisão relevante desta lista, ver
[13-decisoes-tecnicas.md](13-decisoes-tecnicas.md). Para o que ainda falta,
ver [15-pendencias.md](15-pendencias.md).*
