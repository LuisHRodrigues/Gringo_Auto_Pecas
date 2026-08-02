# 09 — Instalação e Configuração

## Pré-requisitos

- **Flutter** (canal `stable`) com suporte a Dart `>=3.3.0 <4.0.0`.
- Para builds nativas: Android Studio/SDK (Android), Xcode (iOS/macOS),
  Visual Studio com workload de Desktop C++ (Windows), toolchain GTK/CMake
  (Linux) — conforme a plataforma-alvo.
- Uma conta e um projeto no **Firebase** com Authentication e Firestore
  habilitados (o projeto já vem configurado para `gringomotopecas-c285e`;
  para rodar contra um projeto próprio, veja "Como configurar banco e
  serviços" abaixo).
- (Opcional, só para gerar o instalador Windows localmente) **Inno Setup 6**.

## Como instalar

```bash
git clone <url-do-repositório>
cd motogest
flutter pub get
```

Se as pastas de plataforma (`android/`, `ios/`, `windows/` etc.) não
existirem no seu checkout:

```bash
flutter create .
flutter pub get
```

## Variáveis de ambiente

O projeto **não usa arquivo `.env`** nem `--dart-define` para segredos de
runtime. A configuração do Firebase é resolvida em tempo de compilação a
partir de `lib/firebase_options.dart` (gerado por `flutterfire configure`) —
não há variável de ambiente a exportar para rodar o app localmente.

As únicas "variáveis" relevantes são de **build/CI**, definidas dentro dos
próprios workflows (não como secrets):

| Variável | Onde é usada | Valor |
| --- | --- | --- |
| `FLUTTER_CHANNEL` | `ci.yml`, `release-build.yml` | `stable` |
| `PUB_CACHE` | `ci.yml`, `release-build.yml` | Diretório de cache de pacotes Dart, dentro do workspace do runner |
| `MyAppVersion` (`/D` do Inno Setup) | `release-build.yml`, passado ao `ISCC.exe` | Extraída da tag de release (`v1.2.0` → `1.2.0`) |

## Como configurar banco e serviços

O app já vem apontando para o projeto Firebase `gringomotopecas-c285e`. Para
usar um projeto Firebase próprio (ex.: ambiente de desenvolvimento
separado):

1. Crie um projeto no [Console Firebase](https://console.firebase.google.com/).
2. Rode `flutterfire configure` na raiz do repositório e selecione o novo
   projeto — isso regenera `lib/firebase_options.dart` e `firebase.json`, e
   baixa um novo `android/app/google-services.json`.
3. No novo projeto, em **Authentication → Sign-in method**, habilite:
   - **Email/senha** (obrigatório para login/cadastro por email).
   - **Google** (opcional, para o botão "Google"). No Android, cadastre
     também a impressão **SHA-1** do app em
     *Project settings → Your apps → Android* e baixe novamente o
     `google-services.json`. Gere o SHA-1 com:
     ```bash
     cd android && ./gradlew signingReport
     ```
4. Implante as regras e índices do Firestore:
   ```bash
   firebase deploy --only firestore:rules
   ```
   (`firestore.indexes.json` está vazio hoje — não há índices compostos
   para implantar, ver [05-banco-de-dados.md](05-banco-de-dados.md)).

> Esses passos de Console (habilitar provedores, cadastrar SHA-1) **não
> podem ser automatizados via CLI/CI** — são configurações únicas feitas
> manualmente uma vez por projeto Firebase.

## Como executar localmente

```bash
flutter run              # dispositivo/emulador padrão detectado
flutter run -d chrome    # no navegador
flutter run -d windows   # desktop Windows
flutter run -d linux     # desktop Linux
flutter run -d macos     # desktop macOS
```

Para builds de release locais (equivalentes ao que o CI produz):

```bash
flutter build windows --release
flutter build web --release
```

Para gerar o instalador Windows localmente (requer Inno Setup 6 instalado):

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" `
  "/DMyAppVersion=1.0.0" `
  "windows\installer\motogest.iss"
```

O instalador é gerado em `dist\gmp-gestor-setup.exe`.
