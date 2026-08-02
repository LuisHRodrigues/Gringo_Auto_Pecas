# 12 — Operação e Manutenção

## Como monitorar o sistema

Não há monitoramento próprio da aplicação (ver
[10-deploy.md](10-deploy.md)). Na prática, monitorar o sistema hoje
significa acompanhar manualmente o **Firebase Console** do projeto
`gringomotopecas-c285e`:

- **Authentication → Users**: volume de contas, últimos logins.
- **Firestore → Uso**: quantidade de leituras/escritas/exclusões (relevante
  porque toda coleção operacional é lida por inteiro a cada sessão —
  `snapshots()` sem filtro — então o consumo de leitura cresce com o volume
  de dados, não com o uso da tela).
- **Firestore → Regras**: erros de `permission-denied` (indicam clientes
  tentando operar sem estar autenticados, ou um bug de sincronização de
  estado do `AuthProvider`/`DataProvider`).

## Logs

- **Não há logs de aplicação centralizados.** Em desenvolvimento, os únicos
  logs disponíveis são o console do `flutter run`/DevTools.
- **Trilha de auditoria mínima nos próprios dados**: `createdBy` +
  `createdAt` em `parts`, `serviceOrders` e `employees` (ver
  [08-seguranca.md](08-seguranca.md)) — útil para investigar "quem criou
  esse registro", mas não "quem editou/excluiu por último".
- Nenhum log de erro de runtime (exceptions não tratadas) é coletado
  remotamente — um crash em produção só é percebido se o usuário reportar.

## Problemas conhecidos

Ver a lista completa e priorizada em
[15-pendencias.md](15-pendencias.md#bugs-conhecidos). Resumo dos mais
relevantes do ponto de vista operacional:

- Fotos de OS gravadas como base64 dentro do documento podem se aproximar do
  limite de 1 MiB por documento do Firestore em OS com várias fotos grandes.
- Sem separação de ambiente dev/produção: testes manuais afetam dados reais.
- Sem RBAC: qualquer conta autenticada tem acesso total aos dados
  operacionais.

## Procedimentos para incidentes

Não há um runbook formal. Na ausência de um, o procedimento mínimo
recomendado para um incidente de dados (ex.: exclusão em massa acidental,
loja apagada por engano) seria:

1. **Conter**: se possível, revogar/alterar temporariamente
  `firestore.rules` para bloquear escrita (`allow write: if false;`) na(s)
  coleção(ões) afetada(s), e reimplantar com
  `firebase deploy --only firestore:rules`, para impedir mais perda de
  dados enquanto se investiga.
2. **Diagnosticar**: verificar no Firebase Console quais documentos foram
  afetados e em que janela de tempo.
3. **Recuperar**: como **não há backup/exportação agendada** (ver
  [10-deploy.md](10-deploy.md)), hoje não existe um caminho automático de
  restauração — a recuperação dependeria de dados que o próprio usuário
  ainda tenha (ex.: em cache local do app) ou de uma exportação manual feita
  antes do incidente, se houver.
4. **Reabrir o acesso** assim que a causa raiz for corrigida.

Essa lacuna de backup/runbook é um risco real e está listada como pendência
prioritária em [15-pendencias.md](15-pendencias.md).

## Como fazer rollback (voltar para uma versão anterior)

- **Do binário/app**: como a distribuição é via GitHub Releases (tags
  `v*.*.*`), o "rollback" é simplesmente orientar os usuários a baixar o
  instalador/artefato de uma tag/release anterior — não há atualização
  automática (auto-update) embutida no app.
- **Do schema/dados no Firestore**: não há mecanismo de rollback de dados,
  já que não há migrations formais nem backups (ver
  [05-banco-de-dados.md](05-banco-de-dados.md) e
  [10-deploy.md](10-deploy.md)). Reverter uma mudança de schema exigiria
  reverter também o código (`models.dart`) para a versão compatível, e
  eventualmente rodar um script manual para ajustar documentos já gravados
  no formato novo.
- **Das regras do Firestore**: como `firestore.rules` é versionado no git,
  reverter é reimplantar a versão anterior do arquivo:
  ```bash
  git show <commit-anterior>:firestore.rules > firestore.rules
  firebase deploy --only firestore:rules
  ```

## Rotinas de manutenção

Não há rotinas agendadas (cron jobs, Cloud Functions de limpeza,
manutenção de índice) configuradas. Manutenção até hoje tem sido pontual e
manual, refletida no histórico de commits (ver
[14-changelog.md](14-changelog.md)) — ex.: remoção de dados de exemplo,
renomeação do projeto, ajustes de gráfico.

Recomenda-se, à medida que o volume de dados crescer, avaliar:

- Uma exportação periódica do Firestore (`gcloud firestore export`) para um
  bucket, como backup mínimo.
- Uma Cloud Function ou rotina manual para arquivar/expurgar transações
  muito antigas, já que hoje toda a coleção `transactions` é carregada por
  inteiro no cliente a cada sessão.
