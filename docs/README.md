# Documentação oficial — GMP Gestor

Este diretório reúne a documentação técnica e de produto do **GMP Gestor**
(pacote Dart `gmp_gestor`), sistema de gestão para oficina de motos construído
em Flutter com backend em Firebase.

Ela foi escrita a partir da inspeção do código-fonte, dos workflows de CI/CD e
do histórico de commits existentes até **02/08/2026**. Onde o projeto não
define algo formalmente (ex.: ambientes de homologação, testes E2E), o
documento correspondente diz isso explicitamente em vez de inventar um
processo que não existe — trate essas seções como lacunas conhecidas, não
como comportamento real do sistema.

## Índice

| Documento | Conteúdo |
| --- | --- |
| [01-visao-geral.md](01-visao-geral.md) | Objetivo, problema resolvido, público-alvo, escopo |
| [02-requisitos.md](02-requisitos.md) | Requisitos funcionais/não funcionais, regras de negócio, restrições |
| [03-arquitetura.md](03-arquitetura.md) | Visão geral, componentes, comunicação, stack, diagrama |
| [04-estrutura-do-projeto.md](04-estrutura-do-projeto.md) | Organização de pastas, responsabilidade de cada módulo |
| [05-banco-de-dados.md](05-banco-de-dados.md) | Coleções do Firestore, campos, relacionamentos, integridade |
| [06-api.md](06-api.md) | Como o app acessa dados (não há API REST própria) |
| [07-funcionalidades.md](07-funcionalidades.md) | Telas, fluxos do usuário, regras de cada tela |
| [08-seguranca.md](08-seguranca.md) | Autenticação, autorização, proteção de dados, secrets |
| [09-instalacao.md](09-instalacao.md) | Pré-requisitos, instalação, variáveis de ambiente, execução local |
| [10-deploy.md](10-deploy.md) | Ambientes, processo de deploy, CI/CD, backups, monitoramento |
| [11-testes.md](11-testes.md) | Estratégia de testes, como executar, cobertura atual |
| [12-operacao.md](12-operacao.md) | Monitoramento, logs, incidentes, rollback, manutenção |
| [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md) | Decisões técnicas e seus motivos |
| [14-changelog.md](14-changelog.md) | Histórico de versões e alterações |
| [15-pendencias.md](15-pendencias.md) | Bugs conhecidos, melhorias futuras, dívidas técnicas |

## Como manter esta documentação

- Sempre que uma regra de negócio, coleção do Firestore ou fluxo de tela
  mudar no código, atualize o documento correspondente na mesma
  contribuição/PR.
- Novas decisões técnicas relevantes (troca de dependência, mudança de
  arquitetura) devem ser registradas em
  [13-decisoes-tecnicas.md](13-decisoes-tecnicas.md), incluindo o motivo.
- Toda alteração visível ao usuário final deve ganhar uma linha em
  [14-changelog.md](14-changelog.md).
