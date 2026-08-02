# 15 — Pendências

## Bugs conhecidos

Não há bugs abertos formalmente registrados (não há issue tracker
referenciado neste repositório). A partir da inspeção do código, os
seguintes comportamentos são **riscos/defeitos latentes**, não confirmados
em produção:

- **Fotos de OS não sincronizam entre dispositivos no mobile/desktop**: no
  mobile/desktop, `ServiceOrder.photos` guarda o **caminho local do
  arquivo** (não um base64 nem uma URL). Se a mesma OS for aberta em outro
  aparelho, a foto não existe naquele caminho e a UI cai no ícone de
  "imagem quebrada" (`photoImage()` em `service_orders_page.dart`). Só a web
  (base64) e URLs `http(s)` funcionam de fato entre dispositivos.
- **Limite de 5MB por foto anunciado na UI, mas não validado no código**: o
  texto "Você pode adicionar até 3 fotos (máx. 5MB cada)" é apenas
  informativo — `_pickPhoto()` não checa o tamanho do arquivo selecionado.
  Uma foto grande pode aproximar o documento da OS do limite de 1 MiB do
  Firestore (ver [05-banco-de-dados.md](05-banco-de-dados.md)) e falhar a
  escrita sem uma mensagem específica (cai no erro genérico de
  `runGuarded`).
- **`PartUsed`/`partsUsed` sem uso real**: o modelo existe
  (`lib/models/models.dart`) e o campo é persistido em `serviceOrders`, mas
  nenhum formulário atual permite vincular peças usadas a uma OS — é sempre
  `[]`. Isso significa que o valor total da OS não é derivado
  automaticamente de peças + mão de obra; é digitado manualmente, com risco
  de divergência entre o que foi "usado" e o que foi cobrado.
- **Categoria "Peças" duplicada em duas fontes**: dentro do módulo
  Finanças, "Peças" é uma categoria fixa (`_kEntradaCatsOficina`/
  `_kSaidaCatsOficina`) só para a loja `motogest`, sem qualquer vínculo com
  o estoque real da coleção `parts` — uma "Compra de Peças" lançada em
  Finanças não debita/credita o campo `stock` de nenhuma peça.
- **`barcode` em `MotorcyclePart` sem tela de uso**: o campo existe no
  modelo e é persistido, mas nenhum formulário de peça o exibe ou edita —
  hoje é sempre `null` para peças criadas pela UI atual.

## Melhorias futuras

Sugestões derivadas das lacunas identificadas nesta documentação (não são
compromissos de roadmap, apenas oportunidades observadas):

- Implementar upload real de fotos para o **Firebase Storage**, guardando
  apenas a URL no documento da OS — resolveria tanto a sincronização entre
  dispositivos quanto o risco de limite de tamanho de documento.
- Vincular `partsUsed` a um fluxo real de seleção de peças no formulário de
  OS, com baixa automática de estoque ao concluir a ordem.
- Adicionar RBAC básico (ex.: só "gerente"/"caixa" podem excluir
  peças/funcionários/lojas), hoje inexistente (ver
  [08-seguranca.md](08-seguranca.md)).
- Adicionar testes de widget para as telas principais e testes de
  integração contra o Firebase Emulator Suite (ver
  [11-testes.md](11-testes.md)).
- Configurar Crashlytics/Analytics ou equivalente para visibilidade de erros
  em produção (ver [10-deploy.md](10-deploy.md) e
  [12-operacao.md](12-operacao.md)).
- Separar ambientes de desenvolvimento/homologação/produção com projetos
  Firebase distintos.
- Configurar backup/exportação periódica do Firestore.
- Estender o pipeline de release (`release-build.yml`) para também publicar
  builds Android/Linux/macOS, hoje fora do CI de release.

## Funcionalidades planejadas

Não há um roteiro de funcionalidades futuras documentado no repositório
(sem arquivo de roadmap, backlog ou milestones do GitHub referenciados).
Qualquer item aqui seria especulação — esta seção deve ser preenchida
conforme decisões de produto forem tomadas.

## Dívidas técnicas

- **Sem separação de camada de repositório**: `DataProvider` acumula estado
  de UI e acesso a dados no mesmo arquivo/classe (ver
  [04-estrutura-do-projeto.md](04-estrutura-do-projeto.md)); dificulta testar
  a lógica de agregação (ex.: `transactionsOf`) sem instanciar o Firestore
  de verdade.
- **Acoplamento direto a `FirebaseAuth.instance`/`FirebaseFirestore.instance`**:
  sem injeção de dependência, o que impede mocks/testes de unidade dos
  providers (ver [11-testes.md](11-testes.md)).
- **Identificadores nativos legados** (`com.example.motogest` em
  Android/iOS/macOS) apesar da renomeação do app para "GMP Gestor" — precisa
  ser resolvido antes de qualquer publicação em loja de apps (ver
  [02-requisitos.md](02-requisitos.md) e
  [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md)).
- **Assinatura de build Android usando chave de debug em release**
  (`signingConfig = signingConfigs.getByName("debug")` em
  `android/app/build.gradle.kts`) — funcional para `flutter run --release`
  local, mas **não deve ser usado para publicar** um APK/AAB real sem
  configurar uma keystore de produção própria.
- **Nenhum índice composto declarado** (`firestore.indexes.json` vazio) —
  não é um problema hoje, mas qualquer nova tela que combine `where` +
  `orderBy` em campos diferentes vai exigir declarar e implantar um índice
  aqui antes de funcionar em produção.
- **Sem migrations formais**: mudanças de schema dependem de tornar campos
  novos opcionais no modelo Dart (ver
  [05-banco-de-dados.md](05-banco-de-dados.md)) — funciona para adições,
  mas não há um processo para remoções/renomeações de campo em documentos já
  existentes.
- **Filtragem 100% client-side**: toda coleção operacional é carregada por
  inteiro em cada sessão (sem paginação); não é um problema no volume de
  dados atual de uma oficina pequena, mas não escala indefinidamente (ver
  [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md)).
