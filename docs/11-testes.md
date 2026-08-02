# 11 — Testes

## Estratégia de testes

A estratégia atual é **mínima e concentrada em lógica pura**: os dois
arquivos de teste existentes cobrem apenas funções utilitárias sem
dependência de widget tree completa ou de Firebase. **Não há testes das
telas, dos providers (`AuthProvider`/`DataProvider`) nem integração real com
Firestore/Auth** (nem mesmo com emuladores).

| Nível | Existe? | Onde |
| --- | --- | --- |
| Testes unitários (funções puras) | Sim | `test/input_formatters_test.dart`, `test/widget_test.dart` |
| Testes de widget (telas/componentes) | Não | — |
| Testes de integração (Firebase Emulator Suite, por exemplo) | Não | — |
| Testes de ponta a ponta (E2E, ex. `integration_test`) | Não | — |

## Testes unitários

### `test/input_formatters_test.dart`

Cobre `lib/utils/input_formatters.dart`:

- `cpfInputFormatter`: formata 11 dígitos em `000.000.000-00`, ignora letras
  digitadas, trunca em 11 dígitos.
- `phoneInputFormatter`: celular (11 dígitos) usa hífen após o 5º dígito do
  número; fixo (10 dígitos) usa hífen após o 4º; ignora letras.
- `CurrencyInputFormatter`: trata dígitos como centavos (`"1234"` →
  `"R$ 12,34"`); campo vazio permanece vazio.
- `parseCurrencyInput`: extrai o valor numérico de um texto formatado
  (`"R$ 1.234,56"` → `1234.56`) e de string vazia (`0`).

### `test/widget_test.dart`

Apesar do nome (herdado do template padrão do `flutter create`), **hoje só
testa funções de formatação** de `lib/widgets/common.dart`, não widgets:

- `formatCurrency`: formata em Real (ex.: `1234.5` → contém `"1.234,50"` e
  começa com `"R$"`).
- `formatDate`: `'2026-07-29T10:00:00.000'` → `'29/07/2026'`.
- `formatDateTime`: `'2026-07-29T10:05:00.000'` → `'29/07/2026 10:05'`.

## Testes de integração

Não implementados. Não há `firebase_emulator.json`/Firebase Emulator Suite
configurado, nem mocks de `FirebaseAuth`/`FirebaseFirestore` usados em teste
— `AuthProvider` e `DataProvider` instanciam `FirebaseAuth.instance` e
`FirebaseFirestore.instance` diretamente, o que os torna difíceis de testar
isoladamente sem uma refatoração para injeção de dependência.

## Testes de ponta a ponta

Não implementados. O pacote `integration_test` (padrão do Flutter para E2E)
não está nas dependências do `pubspec.yaml`.

## Como executar os testes

```bash
flutter test
```

Roda automaticamente também no CI, em todo push/PR para `main`
(`.github/workflows/ci.yml`, passo "Rodar testes"), precedido por:

```bash
dart format --output=none --set-exit-if-changed .   # verifica formatação
flutter analyze --no-fatal-infos                     # análise estática
```

Para rodar um único arquivo:

```bash
flutter test test/input_formatters_test.dart
```

## Critérios para considerar o projeto aprovado

Não há um documento formal de "Definition of Done" ou critérios de release
no repositório. Com base no que o CI realmente impõe hoje
(`.github/workflows/ci.yml`), o critério mínimo automatizado é:

1. `dart format` não aponta diferenças (`--set-exit-if-changed`).
2. `flutter analyze --no-fatal-infos` não retorna erros/warnings (infos são
   toleradas).
3. `flutter test` passa (cobrindo apenas os utilitários descritos acima).

Isso **não garante** que uma tela funcione corretamente de ponta a ponta —
validação funcional de UI hoje depende de teste manual (ver
[15-pendencias.md](15-pendencias.md) para a lacuna de cobertura de testes).
