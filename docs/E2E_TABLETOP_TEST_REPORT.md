# 🧪 Relatório Executivo de Testes E2E de Mesa (Tabletop Verification)
**Data da Execução:** 05/08/2026 19:42:05
**Resultado Geral:** `6/6 Casos de Uso Aprovados`

## 📊 Matriz de Cobertura e Validação de Casos de Uso

| Caso de Uso | Nome do Fluxo E2E | Status | Detalhes da Validação |
| :--- | :--- | :--- | :--- |
| `UC-01` | **Autenticação IAM & Seleção Contextual de Unidade/Perfil** | ✅ PASSED | JWT gerado; 2 unidades mapeadas; Unidade ativa: SP-FARIALIMA |
| `UC-02` | **Venda em Campo Offline-First & Captura de Assinatura** | ✅ PASSED | Pedido PED-2026-OFFLINE-001 retido em IndexedDB com assinatura válida. |
| `UC-03` | **Reconexão & Engine de Sincronização em Segundo Plano** | ✅ PASSED | Pedido PED-2026-OFFLINE-001 sincronizado com sucesso no Supabase (201 Created). |
| `UC-04` | **Pré-Visualização Espelho (DANFE/NFC-e) & Exportação XML ERP** | ✅ PASSED | Espelho renderizado e lote XML gerado conforme Schema ERP v2.4. |
| `UC-05` | **Troca Contextual de Unidade em Tempo de Execução** | ✅ PASSED | Contexto alterado para RJ-CENTRO. Filtro RLS aplicado com sucesso. |
| `UC-06` | **Recuperação de Desastres & Reset Seguro de Banco Local** | ✅ PASSED | Reset de IndexedDB local executado com segurança (zero pendências não sincronizadas). |

## 📝 Detalhamento de Passos por Caso de Uso

### [UC-01] Autenticação IAM & Seleção Contextual de Unidade/Perfil
*Usuário realiza login com credencial única e carrega acessos atribuídos (multi-unidade).*

**Passos de Execução:**
- 1. Usuário informa e-mail e senha no formulário de login.
- 2. Sistema valida credenciais e retorna Token JWT de sessão (auth.uid).
- 3. Consulta tabela usuario_perfis_unidades identificando SP-FARIALIMA (Padrão) e RJ-CENTRO.
- 4. Carrega dashboard no contexto da Unidade SP-FARIALIMA com perfil VENDEDOR_CAMPO.

**Resultado da Validação:** `PASSED` — *JWT gerado; 2 unidades mapeadas; Unidade ativa: SP-FARIALIMA*

### [UC-02] Venda em Campo Offline-First & Captura de Assinatura
*Vendedor cria pedido sem sinal de internet; dados e assinatura são retidos no IndexedDB local.*

**Passos de Execução:**
- 1. Vendedor seleciona cliente da carteira local no PWA.
- 2. Adiciona itens ao pedido (SKU: HW-SRV-R750, Qtd: 1).
- 3. Cliente assina digitalmente na tela (captura Base64 PNG).
- 4. Pedido é salvo no IndexedDB local com status 'pendente_sync'.

**Resultado da Validação:** `PASSED` — *Pedido PED-2026-OFFLINE-001 retido em IndexedDB com assinatura válida.*

### [UC-03] Reconexão & Engine de Sincronização em Segundo Plano
*Dispositivo detecta sinal online e sincroniza lote de pedidos pendentes com Supabase PostgreSQL.*

**Passos de Execução:**
- 1. Evento de rede 'online' é disparado no navegador.
- 2. Engine de Sync busca pedidos com status 'pendente_sync' no IndexedDB.
- 3. Envia POST para /pedidos com Bearer JWT.
- 4. Validação de RLS autoriza gravação na unidade do vendedor.
- 5. Atualiza estado local para 'sincronizado'.

**Resultado da Validação:** `PASSED` — *Pedido PED-2026-OFFLINE-001 sincronizado com sucesso no Supabase (201 Created).*

### [UC-04] Pré-Visualização Espelho (DANFE/NFC-e) & Exportação XML ERP
*Geração de espelho visual para conferência e exportação de lote XML estruturado para faturamento.*

**Passos de Execução:**
- 1. Vendedor abre detalhes do pedido sincronizado.
- 2. Clica em 'Espelho NF-e' / 'Cupom Fiscal' para conferência visual prévia.
- 3. Clica em 'Baixar XML de Integração'.
- 4. Sistema gera arquivo XML no schema 'LoteIntegracaoERP' v2.4.

**Resultado da Validação:** `PASSED` — *Espelho renderizado e lote XML gerado conforme Schema ERP v2.4.*

### [UC-05] Troca Contextual de Unidade em Tempo de Execução
*Usuário altera unidade de trabalho de SP-FARIALIMA para RJ-CENTRO; RLS filtra carteira e estoque.*

**Passos de Execução:**
- 1. Usuário clica no seletor de unidade no cabeçalho.
- 2. Seleciona a unidade 'RJ-CENTRO'.
- 3. PWA envia header/contexto para a nova unidade.
- 4. RLS bloqueia exibição de clientes e pedidos de SP, exibindo apenas dados do RJ.

**Resultado da Validação:** `PASSED` — *Contexto alterado para RJ-CENTRO. Filtro RLS aplicado com sucesso.*

### [UC-06] Recuperação de Desastres & Reset Seguro de Banco Local
*Limpeza manual ou recuperação de estouro de quota no IndexedDB sem afetar dados no Supabase.*

**Passos de Execução:**
- 1. Usuário aciona opção de reset de banco local.
- 2. Sistema verifica se existem pedidos com status 'pendente_sync'.
- 3. Se houver pendências, exige confirmação explícita ou força sincronização prévia.
- 4. Limpa IndexedDB local e recarrega dados atualizados do Supabase.

**Resultado da Validação:** `PASSED` — *Reset de IndexedDB local executado com segurança (zero pendências não sincronizadas).*
