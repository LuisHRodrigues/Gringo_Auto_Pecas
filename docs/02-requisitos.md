# 02 — Requisitos

## Requisitos funcionais (o que o sistema deve fazer)

### Autenticação (RF-01 a RF-08)

| ID | Requisito |
| --- | --- |
| RF-01 | O sistema deve permitir cadastro com nome, email e senha (mínimo 6 caracteres). |
| RF-02 | O sistema deve permitir login com email e senha. |
| RF-03 | O sistema deve permitir login/cadastro com conta Google. |
| RF-04 | Após o cadastro por email, o sistema deve enviar um email de verificação e exibir uma tela de confirmação. |
| RF-05 | O usuário deve poder continuar usando o sistema mesmo sem confirmar o email (a verificação não é bloqueante em logins futuros). |
| RF-06 | O sistema deve verificar automaticamente, a cada 5 segundos, se o email foi confirmado enquanto a tela de confirmação está aberta. |
| RF-07 | O usuário deve poder reenviar o email de verificação e fazer logout a partir da tela de confirmação. |
| RF-08 | O sistema deve manter um perfil (`users/{uid}`) com nome, email e avatar de cada usuário autenticado. |

### Peças (RF-09 a RF-14)

| ID | Requisito |
| --- | --- |
| RF-09 | O sistema deve permitir cadastrar uma peça com código, nome, categoria, marca, preço e estoque. |
| RF-10 | O sistema deve permitir editar e excluir uma peça existente. |
| RF-11 | O sistema deve permitir buscar peças por nome, código, categoria ou marca. |
| RF-12 | O sistema deve exibir estatísticas agregadas: total de peças, valor total em estoque, quantidade com estoque baixo (≤ 5 unidades) e sem estoque (0 unidades). |
| RF-13 | O sistema deve registrar quem cadastrou cada peça (nome, email, data). |
| RF-14 | O sistema deve refletir imediatamente (tempo real) qualquer alteração de estoque para todos os usuários logados. |

### Ordens de serviço (RF-15 a RF-24)

| ID | Requisito |
| --- | --- |
| RF-15 | O sistema deve permitir criar uma OS com dados do cliente, da moto, problema relatado, mecânico responsável, mão de obra e valor total. |
| RF-16 | O sistema deve permitir anexar até 3 fotos por OS. |
| RF-17 | O sistema deve permitir selecionar como mecânico responsável apenas funcionários com cargo "Mecânico" e status "Ativo". |
| RF-18 | O sistema deve manter visível, mesmo assim, o mecânico já vinculado a uma OS existente caso ele tenha sido inativado ou removido depois. |
| RF-19 | O sistema deve permitir alterar o status da OS entre pendente, em andamento, concluída e cancelada. |
| RF-20 | Ao marcar uma OS como concluída, o sistema deve registrar automaticamente a data/hora de conclusão. |
| RF-21 | O sistema deve permitir editar e excluir uma OS existente. |
| RF-22 | O sistema deve permitir buscar OS por número, cliente, placa ou mecânico. |
| RF-23 | O sistema deve exibir uma tela de detalhes com todos os dados da OS, incluindo visualização ampliada das fotos (zoom/pan). |
| RF-24 | O sistema deve exibir estatísticas agregadas por status (pendentes, em andamento, concluídas). |

### Funcionários (RF-25 a RF-29)

| ID | Requisito |
| --- | --- |
| RF-25 | O sistema deve permitir cadastrar funcionário com nome, CPF, cargo, telefone, email, data de admissão, salário e status. |
| RF-26 | O sistema deve aplicar máscara de CPF (`000.000.000-00`) e telefone (fixo/celular) durante a digitação. |
| RF-27 | O sistema deve permitir editar, excluir e buscar funcionários (nome, CPF, email, telefone). |
| RF-28 | O sistema deve exibir estatísticas agregadas: total, ativos, mecânicos ativos e inativos. |
| RF-29 | Cargos suportados: mecânico, atendente, gerente, caixa. Status suportados: ativo, inativo. |

### Busca de peças (RF-30 a RF-32)

| ID | Requisito |
| --- | --- |
| RF-30 | O sistema deve oferecer um catálogo somente leitura com filtros combináveis por texto, categoria, marca e disponibilidade (em estoque / estoque baixo / sem estoque). |
| RF-31 | O sistema deve permitir limpar todos os filtros de uma vez. |
| RF-32 | O sistema deve exibir a contagem de peças encontradas. |

### Finanças (RF-33 a RF-46)

| ID | Requisito |
| --- | --- |
| RF-33 | O sistema deve suportar múltiplas "lojas" (negócios), cada uma com nome, tipo e cor. Existe sempre uma loja padrão (`motogest`, "MotoGest Oficina"), criada automaticamente no primeiro login se ainda não existir. |
| RF-34 | O sistema deve permitir adicionar e remover lojas (exceto a loja padrão, que não pode ser removida pela UI). |
| RF-35 | Ao remover uma loja, o sistema deve remover também suas transações e categorias personalizadas. |
| RF-36 | O sistema deve permitir lançar transações manuais de entrada ou saída, com categoria, descrição, valor e data. |
| RF-37 | O sistema deve oferecer categorias padrão por tipo (entrada/saída), com categorias extras específicas da loja principal ("Peças" — venda/compra de peças). |
| RF-38 | O sistema deve permitir criar, renomear e excluir categorias personalizadas por loja e tipo. |
| RF-39 | Ao renomear uma categoria, o sistema deve migrar todas as transações da mesma loja que usavam o nome antigo. |
| RF-40 | O sistema deve importar automaticamente, como receita ("Serviços"), toda OS com status "Concluída" — apenas na loja principal (`motogest`) — sem duplicar o lançamento. |
| RF-41 | O sistema deve permitir selecionar o mês visualizado; a lista de meses disponíveis deve incluir o mês atual e todos os meses com transações (inclusive as derivadas de OS concluídas). |
| RF-42 | O sistema deve calcular e exibir total de entradas, total de saídas, balanço (lucro/prejuízo) e margem de lucro do mês/loja selecionados. |
| RF-43 | O sistema deve exibir gráfico de evolução mensal (entradas x saídas), gráfico de lucro mensal, gráfico de receitas por categoria (pizza) e gráfico de despesas por categoria (barras) — últimos 6 meses com dados. |
| RF-44 | O sistema deve exibir uma tabela com as 10 transações mais recentes do mês/loja selecionados. |
| RF-45 | O sistema deve impedir o cadastro de transação sem categoria, descrição ou valor válido (> 0). |
| RF-46 | O sistema deve impedir categorias duplicadas (case-insensitive) dentro do mesmo tipo/loja, inclusive contra as categorias padrão. |

## Requisitos não funcionais

| ID | Categoria | Requisito |
| --- | --- | --- |
| RNF-01 | Segurança | Toda operação de leitura/escrita nas coleções operacionais deve exigir usuário autenticado (`request.auth != null`), reforçado por `firestore.rules`. |
| RNF-02 | Segurança | O documento de perfil (`users/{uid}`) só pode ser escrito pelo próprio usuário dono do uid. |
| RNF-03 | Disponibilidade | Os dados devem refletir em tempo real (sem necessidade de recarregar a tela) entre todos os clientes conectados, via listeners `snapshots()` do Firestore. |
| RNF-04 | Confiabilidade | Uma falha de escrita no Firestore não deve travar a UI silenciosamente — deve exibir uma mensagem de erro ao usuário (`runGuarded`, ver `lib/widgets/common.dart`). |
| RNF-05 | Usabilidade | A interface deve ser responsiva, adaptando grids e menus entre layouts de celular e desktop/web (breakpoints em `LayoutBuilder`/`MediaQuery`, tipicamente 640/768/1024px). |
| RNF-06 | Internacionalização | O app é localizado apenas em `pt_BR` (datas, moeda e todos os textos fixos em português; não há suporte a outros idiomas). |
| RNF-07 | Portabilidade | O app deve compilar e rodar em Android, iOS, Web, Windows, Linux e macOS a partir da mesma base de código Flutter (embora apenas Windows e Web tenham pipeline de build automatizado — ver [10-deploy.md](10-deploy.md)). |
| RNF-08 | Compatibilidade | `firebase_auth` exige `minSdk 23+` no Android (`android/app/build.gradle.kts`). |
| RNF-09 | Manutenibilidade | Análise estática (`flutter analyze`) e formatação (`dart format`) devem passar sem erros em todo push/PR para `main` (ver `ci.yml`). |
| RNF-10 | Consistência de dados | Transações derivadas de OS concluída não devem ser persistidas como documentos duplicados — devem ser calculadas em tempo real a partir do status da OS (`DataProvider._ordersAsTransactions`). |

## Regras de negócio

Consolidação das regras já detalhadas nos requisitos funcionais acima, para
referência rápida:

1. **Estoque de peça**: `stock == 0` → badge "Sem estoque" (destrutivo);
   `1 ≤ stock ≤ 5` → badge de estoque baixo (aviso); `stock > 5` → disponível.
2. **Mecânico de uma OS**: só funcionários com `role == 'mechanic'` e
   `status == 'active'` aparecem como opção nova; um mecânico já vinculado que
   deixou de atender esse critério continua aparendo, marcado como
   "(indisponível)".
3. **Conclusão de OS**: mudar o status para `completed` grava
   `completedAt = agora` (se ainda não tiver); mudar para qualquer outro
   status limpa o vínculo apenas se já não havia data — o formulário
   preserva a data original ao reabrir uma OS já concluída.
4. **Transação sintética de OS**: apenas OS com `status == 'completed'`
   viram uma transação `entrada`/`Serviços` no valor de `totalCost`,
   **apenas para a loja `motogest`**; o `id` sintético tem o prefixo `os-` e
   nunca é gravado no Firestore.
5. **Exclusão de loja**: não é oferecida para a loja `motogest` na UI;
   remover qualquer outra loja também apaga (em lote/`batch`) suas
   transações e categorias.
6. **Categorias**: duplicidade é verificada por nome (case-insensitive)
   contra as categorias padrão do tipo/loja **e** contra as personalizadas já
   cadastradas. Renomear uma categoria atualiza também as transações que já
   usavam o nome antigo, na mesma loja.
7. **Senha**: mínimo de 6 caracteres tanto no cadastro quanto na mensagem de
   erro (`weak-password`) do Firebase.
8. **Email**: validado no cliente por regex antes do cadastro
   (`_emailRegex` em `login_page.dart`); mensagens de erro do Firebase Auth
   são traduzidas para PT-BR (`AuthProvider._messageFor`).

## Restrições e dependências

- **Restrição de nomenclatura legada**: o projeto foi renomeado de
  "MotoGest" para "GMP Gestor" (commit `bcbe096`), mas os identificadores
  nativos de plataforma **não** foram atualizados:
  - Android: `namespace`/`applicationId` = `com.example.motogest`.
  - iOS/macOS: `PRODUCT_BUNDLE_IDENTIFIER` = `com.example.motogest`
    (e `com.example.motogest.RunnerTests` nos testes).
  - Windows: binário `gmp_gestor.exe` (`BINARY_NAME` já atualizado em
    `windows/CMakeLists.txt`), mas o instalador Inno Setup ainda vive em
    `windows/installer/motogest.iss`.
- **Dependência de projeto Firebase único**: `lib/firebase_options.dart` e
  `firebase.json` apontam para o projeto `gringomotopecas-c285e`; não há
  configuração para múltiplos ambientes (dev/hml/prod) — ver
  [10-deploy.md](10-deploy.md).
- **Dependência de provedores habilitados manualmente**: Email/Senha e
  Google precisam ser habilitados manualmente no Console Firebase; isso não
  é (e não pode ser) automatizado via CLI/CI (ver
  [09-instalacao.md](09-instalacao.md)).
- **Restrição de tamanho de documento do Firestore**: como as fotos das OS
  são guardadas como base64 dentro do próprio documento (não em Storage), o
  documento de uma OS com 3 fotos grandes pode se aproximar do limite de
  1 MiB por documento do Firestore — não há validação de tamanho de arquivo
  no código (apesar do texto da UI dizer "máx. 5MB cada"). Ver
  [15-pendencias.md](15-pendencias.md).
- **Dependência de SDK**: `sdk: ">=3.3.0 <4.0.0"` (Dart), canal `stable` do
  Flutter (usado também no CI via `subosito/flutter-action@v2`).
- **Dependência externa de terceiros**: Firebase (Authentication +
  Firestore) é uma dependência de infraestrutura crítica — o app não
  funciona (além da tela de login) sem conectividade com o Firebase.
