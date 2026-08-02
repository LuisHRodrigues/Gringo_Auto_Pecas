# 01 — Visão Geral

## Nome do projeto

**GMP Gestor** (pacote Dart: `gmp_gestor`; binário/executável Windows:
`gmp_gestor.exe`). O projeto foi originalmente criado como "MotoGest" — nome
que ainda aparece em identificadores legados não renomeados (ver
[Restrições e dependências](02-requisitos.md#restrições-e-dependências) em
02-requisitos.md).

## Objetivo

Digitalizar a gestão do dia a dia de uma oficina de motos: controle de
estoque de peças, abertura e acompanhamento de ordens de serviço (OS),
cadastro de funcionários e controle financeiro (receitas/despesas por loja),
com dados sincronizados em tempo real na nuvem entre todos os dispositivos e
usuários da equipe.

## Problema que resolve

Oficinas pequenas/médias tipicamente controlam peças, OS e caixa em
planilhas, papel ou cadernos separados, o que gera:

- Falta de visibilidade em tempo real do estoque (peça vendida por um
  funcionário não aparece imediatamente para os demais).
- Nenhum vínculo automático entre uma OS concluída e o financeiro (a receita
  do serviço precisa ser lançada manualmente).
- Ausência de histórico auditável de quem cadastrou o quê (peça, OS,
  funcionário) e quando.
- Dificuldade de consolidar múltiplos negócios/lojas em uma única visão
  financeira.

O GMP Gestor resolve isso concentrando essas quatro frentes num único app,
com um único backend (Firebase) compartilhado por toda a equipe logada.

## Público-alvo

- **Oficinas de moto de pequeno/médio porte** com uma equipe pequena
  (atendentes, mecânicos, gerente/caixa) que compartilha o mesmo sistema.
- Donos de oficina que também administram negócios paralelos (pet shop,
  padaria etc.) e querem controlar o financeiro de todos em um só lugar — daí
  o conceito de "múltiplas lojas" dentro do módulo Finanças.
- Não é multi-tenant: o modelo de dados assume **uma única oficina** cujos
  dados são compartilhados por todos os usuários autenticados (ver
  [03-arquitetura.md](03-arquitetura.md)).

## Escopo

### O que o sistema faz

- Login/cadastro com email+senha ou Google (Firebase Authentication real).
- Confirmação de email pós-cadastro (não bloqueante).
- CRUD de peças de moto, com busca e indicadores de estoque baixo/zerado.
- CRUD de ordens de serviço, com upload de até 3 fotos, vínculo com um
  mecânico ativo cadastrado, e cálculo de valor total (mão de obra + peças).
- CRUD de funcionários, com cargos (mecânico, atendente, gerente, caixa) e
  status ativo/inativo.
- Catálogo de busca de peças com filtros por categoria, marca e
  disponibilidade (tela somente leitura, sem CRUD).
- Módulo financeiro com múltiplas lojas, lançamentos manuais de
  entrada/saída, categorias personalizáveis por loja, gráficos mensais e
  importação automática de OS concluídas como receita.
- Sincronização em tempo real entre todos os usuários logados via listeners
  do Cloud Firestore.

### O que o sistema **não** faz

- **Não é multi-tenant**: não há isolamento de dados entre "oficinas"
  diferentes — qualquer usuário autenticado no mesmo projeto Firebase vê os
  mesmos dados operacionais (ver [08-seguranca.md](08-seguranca.md)).
- **Não emite notas fiscais** nem integra com sistemas fiscais/contábeis.
- **Não controla ponto/escala de funcionários** — o cadastro de funcionário é
  apenas um registro (nome, cargo, salário, status), sem folha de pagamento.
- **Não tem controle de acesso por papel (RBAC)**: qualquer usuário logado
  pode ler/escrever qualquer coleção operacional; o "cargo" do funcionário é
  um dado de negócio, não uma permissão de sistema.
- **Não gera relatórios exportáveis** (PDF/Excel) — os dados são visualizados
  apenas dentro do app.
- **Não tem API pública/REST própria** — todo acesso a dados é via SDKs
  cliente do Firebase (ver [06-api.md](06-api.md)).
- **Não faz upload de fotos para um serviço de armazenamento de objetos**
  (Firebase Storage, S3 etc.) — as fotos das OS são guardadas como base64 (na
  web) ou caminho local de arquivo (mobile/desktop) diretamente no documento
  Firestore da OS (ver [05-banco-de-dados.md](05-banco-de-dados.md) e
  [15-pendencias.md](15-pendencias.md)).
