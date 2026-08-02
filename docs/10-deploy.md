# 10 — Deploy e Infraestrutura

## Ambientes: desenvolvimento, homologação e produção

**Não existem ambientes formalmente separados.** Há um único projeto
Firebase (`gringomotopecas-c285e`) usado tanto para desenvolvimento local
quanto para o que seria "produção" — não há um segundo projeto Firebase de
homologação/staging, nem flags de ambiente no app para apontar para bases
diferentes.

Na prática:

| Ambiente | Como existe hoje |
| --- | --- |
| Desenvolvimento | `flutter run` local, contra o mesmo Firestore de produção. |
| Homologação | Não existe. |
| Produção | O mesmo projeto Firebase acima; "release" é apenas o build empacotado e publicado no GitHub Releases. |

Isso é uma lacuna relevante (ver [15-pendencias.md](15-pendencias.md)):
qualquer teste manual feito durante o desenvolvimento local grava dados reais
no mesmo banco usado pelos usuários finais.

## Processo de deploy

Não há "deploy" no sentido de subir um servidor — o "deploy" do app é a
**publicação de um instalador/pacote** que o usuário final baixa e instala.
O processo é inteiramente automatizado por tag Git:

1. Alguém cria e envia uma tag no padrão `v*.*.*` (ex.: `v1.2.0`).
2. O workflow `release-build.yml` é disparado (pushes/PRs comuns **não**
   disparam este workflow).
3. Builda Windows e Web em paralelo, gera o instalador, e publica (ou
   atualiza) um GitHub Release anexando os artefatos.

O deploy das **regras do Firestore** é um passo manual separado, feito por
quem administra o projeto:

```bash
firebase deploy --only firestore:rules
```

Não há automação de CI para esse passo — mudanças em `firestore.rules` não
são implantadas automaticamente ao fazer merge/tag.

## Servidores/cloud

- **Firebase (Google Cloud)**: hospeda Authentication e Firestore. Não há
  servidor próprio (VM, container, função serverless) mantido pelo projeto.
- **GitHub Actions**: runners efêmeros (`windows-latest`, `ubuntu-latest`)
  usados só para compilar e empacotar — não há infraestrutura persistente.
- **GitHub Releases**: hospeda os artefatos binários
  (`gmp-gestor-windows.zip`, `gmp-gestor-setup.exe`, `gmp-gestor-web.zip`).
- **Build web**: gerado (`flutter build web`) e publicado como artefato, mas
  **não há hospedagem configurada** (nem Firebase Hosting, nem qualquer
  outro serviço) — o zip do build web fica disponível apenas para download
  manual no Release, não como um site acessível por URL.

## CI/CD (automação de testes e deploy)

Dois workflows em `.github/workflows/`:

### `ci.yml` — integração contínua

- **Gatilho**: todo push ou pull request para `main`.
- **Passos**: `flutter pub get` → `dart format --output=none --set-exit-if-changed .`
  → `flutter analyze --no-fatal-infos` → `flutter test`.
- **Objetivo**: pegar erro de formatação/análise/teste antes de chegar numa
  tag de release.

### `release-build.yml` — build e publicação de release

- **Gatilho**: push de tag `v*.*.*`.
- **Permissão**: `contents: write` (necessária para anexar artefatos ao
  GitHub Release).
- **Job `windows`** (`windows-latest`):
  1. `flutter config --enable-windows-desktop` → `flutter pub get` →
     `flutter build windows --release`.
  2. Copia `msvcp140*.dll` e `vcruntime140*.dll` (Visual C++ Redistributable)
     para junto do `.exe`, para o app ficar autocontido sem exigir instalação
     manual do redistributable pelo usuário final.
  3. Compacta `build\windows\x64\runner\Release\*` em
     `gmp-gestor-windows.zip` e sobe como artefato `windows-release`.
  4. Roda `ISCC.exe` (Inno Setup 6, já pré-instalado no runner) sobre
     `windows\installer\motogest.iss`, passando a versão da tag via
     `/DMyAppVersion`, gerando `dist\gmp-gestor-setup.exe` — sobe como
     artefato `windows-installer`.
- **Job `web`** (`ubuntu-latest`): `flutter build web --release`, compacta em
  `gmp-gestor-web.zip`, sobe como artefato `web-release`.
- **Job `release`** (`ubuntu-latest`, depende de `windows` e `web`): baixa
  todos os artefatos e usa `softprops/action-gh-release@v2` para
  criar/atualizar o GitHub Release da tag, anexando os três arquivos e
  gerando release notes automáticas (`generate_release_notes: true`).

> Builds para **Android, iOS, Linux e macOS não fazem parte do pipeline de
> release** hoje, mesmo o projeto tendo as pastas nativas dessas plataformas
> geradas pelo Flutter. Se for necessário publicar para essas plataformas,
> o build precisa ser feito manualmente.

## Backups

**Não há rotina de backup configurada** para o Cloud Firestore neste
projeto (nem exportações agendadas via `gcloud firestore export`, nem
qualquer script equivalente). O Firestore mantém a durabilidade padrão do
Google Cloud, mas isso não substitui um backup point-in-time controlado pela
equipe — uma exclusão em massa acidental (ex.: um bug em `deleteStore`
apagando a loja errada) não tem como ser revertida sem uma exportação prévia.
Ver [15-pendencias.md](15-pendencias.md).

## Monitoramento

**Não há monitoramento de aplicação configurado.** Não há Crashlytics,
Sentry, Firebase Performance Monitoring ou Analytics integrados ao app. A
única visibilidade operacional disponível é o próprio Firebase Console
(uso/quota de Firestore e Authentication, logs de erro de regras),
consultado manualmente, fora deste repositório. Ver
[12-operacao.md](12-operacao.md).
