# 13 — Decisões Técnicas

Registro das decisões de arquitetura/implementação identificáveis no código
e no histórico de commits, com o motivo inferido de cada uma.

## Firebase como backend único (BaaS, sem servidor próprio)

**Decisão**: usar Firebase Authentication + Cloud Firestore diretamente do
cliente Flutter, sem servidor de aplicação intermediário.

**Motivo**: o app precisa de sincronização em tempo real entre múltiplos
usuários/dispositivos de uma equipe pequena; o Firestore oferece isso
nativamente (`snapshots()`) sem exigir a equipe construir e operar sua
própria infraestrutura de backend/API. Para o porte de um protótipo Figma
(React + mock de dados) para um app funcional, essa é a rota que entrega
sincronização real com o menor esforço de infraestrutura.

**Trade-off aceito**: nenhum controle de acesso granular por papel (RBAC),
nenhuma validação de schema no servidor, nenhuma API própria a versionar —
ver [08-seguranca.md](08-seguranca.md) e [06-api.md](06-api.md).

## `provider` como gerenciador de estado

**Decisão**: dois `ChangeNotifier` globais (`AuthProvider`, `DataProvider`)
injetados via `MultiProvider`/`ChangeNotifierProxyProvider`, em vez de
Bloc, Riverpod, GetX ou setState local espalhado.

**Motivo**: é a solução mais simples do ecossistema Flutter para estado
compartilhado entre telas irmãs (as 5 abas precisam do mesmo cache de
peças/OS/funcionários), com curva de aprendizado baixa e sem geração de
código.

## `ChangeNotifierProxyProvider` para religar `DataProvider` ao `AuthProvider`

**Decisão**: `DataProvider.syncWithAuth(uid)` cancela e recria todos os
listeners do Firestore sempre que o uid autenticado muda, em vez de criar os
listeners uma única vez no construtor.

**Motivo** (documentado em comentário no próprio código,
`data_provider.dart`): um listener de `snapshots()` que recebe
`permission-denied` (porque foi criado antes do login terminar, ou porque o
usuário deslogou) **não se recupera sozinho** quando a permissão volta a
ficar válida. Recriar os listeners do zero a cada troca de usuário evita
telas travadas mostrando "sem permissão" após um logout/login.

## IDs de documento gerados no cliente (timestamp em ms), não pelo Firestore

**Decisão**: novos registros (peças, OS, funcionários, transações,
categorias, lojas) usam `DateTime.now().millisecondsSinceEpoch.toString()`
como id do documento, chamando `.doc(id).set(...)` em vez de `.add(...)`.

**Motivo provável**: permite que o objeto Dart já tenha um `id` definitivo
*antes* da escrita ser confirmada (necessário porque o formulário retorna o
objeto completo via `Navigator.pop(result)`, e o `DataProvider` só recebe o
objeto pronto para persistir) e simplifica a lógica de "editar = re-`set`
com o mesmo id".

**Trade-off aceito**: risco teórico de colisão entre dois dispositivos
criando um registro no mesmo milissegundo (extremamente improvável, mas
existente) — ver [15-pendencias.md](15-pendencias.md).

## Fotos de OS como base64/caminho local, sem serviço de storage

**Decisão**: `ServiceOrder.photos` guarda strings — base64 data URL na web,
caminho de arquivo local no mobile/desktop — persistidas diretamente dentro
do documento Firestore da OS, em vez de subir os arquivos para o Firebase
Storage e guardar apenas a URL.

**Motivo provável**: evita configurar e cobrar por um segundo serviço
(Storage) e suas próprias regras de segurança, para um app cujo volume de
fotos é pequeno (até 3 por OS). É a opção mais simples de implementar dado
que `image_picker` já retorna bytes/caminho diretamente.

**Trade-off aceito**: risco de aproximar o documento do limite de 1 MiB do
Firestore, e caminho de arquivo local (mobile/desktop) não é sincronizável
entre dispositivos — uma foto anexada em um celular não abre em outro
aparelho, pois o campo guarda um caminho de sistema de arquivos local, não
uma URL. Ver [15-pendencias.md](15-pendencias.md).

## Transações de OS concluída calculadas em runtime, não persistidas

**Decisão**: `DataProvider._ordersAsTransactions()` deriva "receitas" a
partir de `orders.where(status == 'completed')` a cada leitura, com id
sintético (`os-<orderId>`) nunca gravado no Firestore, em vez de criar um
documento real em `transactions` quando uma OS é concluída.

**Motivo**: evita duplicidade e inconsistência (ex.: uma OS reaberta ou
cancelada depois de concluída não deixaria uma transação "órfã" para
apagar manualmente) — a fonte de verdade continua sendo o status da OS.

**Trade-off aceito**: essas "transações" não podem ser editadas ou excluídas
individualmente pela tela de Finanças (só mudando o status da OS
original), e só se aplicam à loja `motogest` (hardcoded).

## Filtragem/busca sempre no cliente, nunca via query do Firestore

**Decisão**: toda coleção é lida por inteiro (`collection('x').snapshots()`,
sem `where`/`orderBy` para as listagens principais); busca por texto,
filtros de categoria/marca/disponibilidade e ordenação de tabelas acontecem
em memória, no Dart.

**Motivo provável**: simplicidade — o Firestore não suporta busca
full-text nativa, e o volume de dados esperado (peças/OS/funcionários de uma
oficina) é pequeno o bastante para caber em memória sem paginação.

**Trade-off aceito**: não escala para um volume muito grande de registros
(toda sessão baixa a coleção inteira); nenhum índice composto foi necessário
até hoje (`firestore.indexes.json` vazio) porque não há filtro
multi-campo nas queries reais.

## Nome do projeto trocado (MotoGest → GMP Gestor) sem renomear identificadores nativos

**Decisão** (commit `bcbe096`, 2026-08-02): renomear o app para "GMP
Gestor" na UI, no `pubspec.yaml` (pacote `gmp_gestor`) e no binário Windows
(`gmp_gestor.exe`), mas **manter** `com.example.motogest` como
`applicationId`/`namespace` Android e `PRODUCT_BUNDLE_IDENTIFIER` em
iOS/macOS.

**Motivo provável**: alterar o `applicationId`/bundle id depois de qualquer
publicação nas lojas (Play Store/App Store) trocaria a identidade do app
para os stores (não seria mais uma atualização, e sim um app novo) — mais
seguro adiar essa troca até decidir publicar formalmente nessas lojas. Ver
a restrição documentada em [02-requisitos.md](02-requisitos.md).

## Instalador Windows via Inno Setup no CI, em vez de MSIX

**Decisão** (commits `2ec776c`/`f51dcef`, 2026-08-02): gerar o instalador
Windows com **Inno Setup** (`ISCC.exe`, já pré-instalado nos runners
`windows-latest` do GitHub Actions) em vez de empacotar como MSIX (formato
nativo do Windows/Microsoft Store).

**Motivo provável**: Inno Setup não exige certificado de assinatura de
código para gerar um `.exe` de instalação funcional (MSIX geralmente exige
assinatura para instalar fora da Store) e já vem pronto no runner, sem passo
de instalação adicional no workflow.

## Verificação de email não bloqueante

**Decisão** (commits `8c1a3c0`/`e9c7cdb`, 2026-07-31): a tela de
confirmação de email só aparece uma vez, logo após o cadastro
(`justSignedUp`), e o usuário pode dispensá-la e seguir usando o sistema
mesmo sem confirmar — logins futuros da mesma conta nunca mais são
bloqueados por isso.

**Motivo provável** (evidenciado pela própria mensagem do segundo commit,
"allow continued access for unverified users"): a intenção inicial
provavelmente bloqueava o acesso até a confirmação, e foi revertida no dia
seguinte — sinal de que travar o acesso causava fricção real (ex.: emails
que demoram a chegar, ou usuários que não confirmam mas precisam trabalhar
imediatamente numa oficina).
