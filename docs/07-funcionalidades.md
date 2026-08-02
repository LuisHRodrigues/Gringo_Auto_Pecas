# 07 — Interface e Funcionalidades

## Principais telas

| Tela | Arquivo | Acesso |
| --- | --- | --- |
| Login / Cadastro | `login_page.dart` | Pública (só aparece se não houver usuário logado) |
| Confirmação de email | `verify_email_page.dart` | Logo após um cadastro por email, na mesma sessão |
| Peças | `parts_management_page.dart` | Aba 1 do menu principal |
| Ordens de Serviço | `service_orders_page.dart` | Aba 2 |
| Funcionários | `employees_page.dart` | Aba 3 |
| Busca de Peças | `search_parts_page.dart` | Aba 4 |
| Finanças | `finances_page.dart` | Aba 5 |

## Fluxo do usuário

```mermaid
flowchart TD
    A[Abrir o app] --> B{Usuário autenticado?}
    B -- não --> C[Tela de Login]
    C -->|Entrar| D{Login válido?}
    D -- não --> C
    D -- sim --> G
    C -->|Criar conta| E[Cadastro: nome, email, senha]
    E --> F[Email de verificação enviado]
    F --> H[Tela "Confirme seu email"]
    H -->|Já confirmei / auto-check 5s| G
    H -->|Continuar sem verificar| G
    H -->|Sair| C
    B -- sim, já verificado ou pulou --> G[HomePage: 5 abas]
    G --> P[Peças]
    G --> O[Ordens de Serviço]
    G --> Fu[Funcionários]
    G --> Bp[Busca de Peças]
    G --> Fi[Finanças]
    O -->|marcar como Concluída| Fi
```

## Descrição das funcionalidades e regras de cada tela

### Login / Cadastro (`login_page.dart`)

- Duas abas: **Login** e **Cadastro**, dentro de um único card centralizado.
- **Login**: campos email + senha, botão "Entrar" e botão "Google"
  (`OutlinedButton.icon`). Erros aparecem como SnackBar vermelho.
- **Cadastro**: campos nome, email, senha (mínimo 6 caracteres, aviso fixo
  abaixo do campo). Validações antes de chamar o Firebase:
  - Nome não pode ser vazio.
  - Email precisa bater com um regex de formato válido.
  - Senha precisa ter ao menos 6 caracteres.
- Ao concluir o cadastro, mostra SnackBar de sucesso e o app avança
  automaticamente para a tela de verificação de email (não é uma navegação
  manual — decorre da mudança de estado do `AuthProvider`).

### Confirmação de email (`verify_email_page.dart`)

- Exibida **uma única vez por sessão**, imediatamente após um cadastro por
  email (controlada por `AuthProvider.justSignedUp`; não volta a aparecer em
  logins futuros da mesma conta, mesmo se o email nunca for confirmado).
- Verifica automaticamente a cada 5 segundos (`Timer.periodic`) se o email já
  foi confirmado, sem exigir ação do usuário.
- Ações manuais disponíveis: "Já confirmei" (força uma checagem imediata,
  com SnackBar se ainda não confirmado), "Reenviar email", "Continuar sem
  verificar agora" (dispensa a tela permanentemente nesta sessão) e "Sair".

### Peças (`parts_management_page.dart`)

- Cabeçalho com 4 `StatCard`: Total de Peças, Valor em Estoque (soma de
  `price * stock`), Estoque Baixo (`0 < stock ≤ 5`), Sem Estoque
  (`stock == 0`).
- Barra de busca (nome, código, categoria ou marca) + botão "Nova Peça".
- Tabela (`DataTable`) com código, nome, categoria, marca, preço, estoque
  (badge colorido), quem cadastrou (tooltip com nome/email/data) e ações
  (editar/excluir).
- Formulário (diálogo modal): código, categoria (dropdown fixo), nome,
  marca, preço (máscara de moeda), estoque (somente dígitos), descrição
  opcional. Todos os campos com `*` são obrigatórios.
- Estado vazio: ícone + "Nenhuma peça cadastrada".

### Ordens de Serviço (`service_orders_page.dart`)

- Cabeçalho com 4 `StatCard`: Total, Pendentes, Em Andamento, Concluídas.
- Busca por número da OS, cliente, placa ou mecânico.
- Tabela com número, cliente, moto (marca+modelo), placa, mecânico, status
  (badge), contagem de fotos, valor total, data e ações
  (ver/editar/excluir).
- **Formulário** (diálogo grande, com seções): número da OS (autogerado,
  campo desabilitado), status, dados do cliente (nome, telefone com
  máscara), dados da moto (marca, modelo, placa), até 3 fotos (upload via
  `image_picker`, galeria), descrição do problema, mecânico responsável
  (dropdown só com funcionários `mechanic`+`active`; mostra o mecânico
  antigo como "(indisponível)" se ele não se qualificar mais), mão de obra e
  valor total (ambos em moeda, digitados manualmente).
- Ao mudar o status para "Concluída", `completedAt` é gravado
  automaticamente (preservado se já existia, ao reabrir para editar).
- **Detalhes**: diálogo somente leitura com todos os dados, fotos em grid
  (clicáveis, abrindo um visualizador em tela cheia com zoom/pan via
  `InteractiveViewer`), valores (mão de obra e total) e metadados de
  criação/conclusão.
- Fotos são armazenadas como base64 (web) ou caminho de arquivo local
  (mobile/desktop) — ver [05-banco-de-dados.md](05-banco-de-dados.md).

### Funcionários (`employees_page.dart`)

- Cabeçalho com 4 `StatCard`: Total, Ativos, Mecânicos (ativos), Inativos.
- Busca por nome, CPF, email ou telefone.
- Tabela com nome, CPF, cargo (rótulo traduzido), telefone, email, data de
  admissão, salário, status (badge) e ações.
- Formulário: nome, CPF (máscara `000.000.000-00`), cargo (dropdown:
  Mecânico/Atendente/Gerente/Caixa), telefone (máscara fixo/celular), email,
  data de admissão (`showDatePicker`), salário (moeda), status
  (Ativo/Inativo). Todos os campos são obrigatórios.

### Busca de Peças (`search_parts_page.dart`)

- Tela **somente leitura** (sem criar/editar/excluir) voltada a consulta
  rápida do catálogo, ex.: por um atendente no balcão.
- Card de filtros: busca textual (nome, código, descrição ou marca),
  categoria (dropdown dinâmico com as categorias já usadas nas peças
  cadastradas), marca (idem), disponibilidade (Todos / Em estoque / Estoque
  baixo / Sem estoque). Botão "Limpar filtros".
- Contador de resultados ("N peças encontradas").
- Resultado em grid de cards (1 a 3 colunas conforme largura da tela), cada
  card com nome, código, badge de disponibilidade, categoria, marca, preço
  em destaque, estoque e descrição (truncada em 2 linhas, se houver).

### Finanças (`finances_page.dart`)

A tela mais complexa do app. Elementos, de cima para baixo:

1. **Cabeçalho**: título + botão "Adicionar Transação" + seletor de mês
   (dropdown com o mês atual e todos os meses com transações, ordem
   decrescente).
2. **Minhas Lojas**: grid de cards (uma por loja cadastrada), clicáveis
   para trocar a loja ativa; botão "Categorias" (gerenciador) e "Adicionar
   Loja". Só a loja ativa mostra o badge "Ativo"; lojas que não são a
   padrão (`motogest`) têm botão de excluir.
3. **Alerta informativo** (só na loja principal): lembra que OS concluídas
   viram receita automaticamente.
4. **Indicador da loja ativa**: nome e tipo do negócio em destaque.
5. **Cards de resumo** (4): Total Entradas, Total Saídas, Balanço do Mês
   (lucro/prejuízo, cor muda conforme sinal), Margem de Lucro (%).
6. **Gráficos** (grid 2×2 em telas largas, empilhado em telas estreitas):
   - *Evolução Mensal*: área entradas (verde) vs. saídas (vermelho), últimos
     até 6 meses com dados.
   - *Lucro Mensal*: linha única (roxo).
   - *Receitas por Categoria*: pizza, com legenda lateral.
   - *Despesas por Categoria*: barras.
   - Todos calculam os limites do eixo Y dinamicamente (`_niceAxisBounds`)
     para produzir marcações "redondas" em vez de valores quebrados.
7. **Transações Recentes**: tabela com as 10 transações mais recentes do
   mês/loja selecionados (data, tipo, categoria, descrição, valor com sinal
   +/− e cor).

**Diálogo — Adicionar Transação**: tipo (Entrada/Saída via `RadioListTile`),
categoria (dropdown combinando categorias padrão + personalizadas da loja;
botão "Nova categoria" abre o gerenciador embutido), descrição, valor
(moeda), data (`showDatePicker`). Validações: categoria obrigatória,
descrição não vazia, valor > 0.

**Diálogo — Adicionar Loja**: nome, tipo de negócio, cor (paleta fixa de 6
cores). Nome e tipo são obrigatórios.

**Diálogo — Gerenciar Categorias**: alterna entre Entrada/Saída
(`ChoiceChip`), lista as categorias personalizadas da loja/tipo (com opção
de renomear/excluir cada uma) e permite adicionar uma nova, bloqueando nomes
duplicados (contra padrão + personalizadas, case-insensitive).

## Prints ou protótipos

Não há protótipos de Figma nem screenshots versionados neste repositório.
O layout, cores e textos foram portados 1:1 do protótipo Figma Make original
("Tela de gerenciamento de peças", React + Tailwind/shadcn) — quem precisar
de referência visual deve consultar esse protótipo original (não versionado
aqui) ou rodar o app localmente (ver [09-instalacao.md](09-instalacao.md)).
