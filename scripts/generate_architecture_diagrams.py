#!/usr/bin/env python3
"""
Script Periférico de Geração de Diagramas Visuais de Arquitetura
Projeto: Ampla Vendas Pro (infointra) - Ampla Informática
Finalidade: Gerar diagramas visuais em formato Mermaid para validação por arquitetos parceiros.
"""

import os
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
DIAGRAMS_DIR = REPO_ROOT / "docs" / "diagrams"

def generate_diagrams():
    DIAGRAMS_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Diagrama de Sequência de Sincronização Offline-to-Online
    seq_file = DIAGRAMS_DIR / "sequence_sync.md"
    seq_content = """# 🔄 Diagrama de Sequência: Sincronização Offline-to-Online

```mermaid
sequenceDiagram
    autonumber
    actor Vendedor as Vendedor de Campo (PWA)
    participant UI as Interface React
    participant IDB as IndexedDB (Browser)
    participant Sync as Sync Engine (Queue)
    participant Auth as Supabase Auth
    participant DB as PostgreSQL (Supabase + RLS)
    participant ERP as API Fiscal / ERP Retaguarda

    Note over Vendedor, IDB: Operação Offline em Campo
    Vendedor->>UI: Digita Pedido de Venda + Captura Assinatura
    UI->>IDB: Salva Pedido (Status: pendente_sync)
    IDB-->>UI: Retorna Sucesso com ID Local

    Note over UI, DB: Conexão Detectada (Online)
    Sync->>Auth: Valida Token JWT da Sessão
    Auth-->>Sync: Token Válido (vendedor_id)
    Sync->>IDB: Busca Pedidos com status: pendente_sync
    IDB-->>Sync: Retorna Lista de Pedidos
    
    loop Para cada pedido pendente
        Sync->>DB: POST /pedidos (Payload + Header Bearer JWT)
        alt Permissão RLS Válida
            DB-->>Sync: 201 Created (ID Supabase + Timestamp)
            Sync->>IDB: Atualiza Status para 'sincronizado'
            DB->>ERP: Dispara Webhook / Fila de Faturamento ERP
            ERP->>ERP: Valida & Transmite SEFAZ (Certificado A1)
        else Falha RLS ou Erro de Conexão
            DB-->>Sync: 401/403/500 Error
            Sync->>IDB: Incrementa Contador de Retentativa (Backoff)
        end
    end
```
"""
    seq_file.write_text(seq_content, encoding="utf-8")

    # 2. Diagrama Entidade-Relacionamento (ER) do Banco Supabase
    er_file = DIAGRAMS_DIR / "er_schema.md"
    er_content = """# 🗄️ Diagrama Entidade-Relacionamento (ER) do Supabase PostgreSQL

```mermaid
erDiagram
    auth_users ||--o{ vendedores : "1 : 1 Vinculo Auth"
    vendedores ||--o{ clientes : "gerencia carteira"
    vendedores ||--o{ pedidos : "emite"
    clientes ||--o{ pedidos : "compra"
    pedidos ||--|{ pedido_itens : "contem"
    produtos ||--o{ pedido_itens : "referenciado por SKU"
    condicoes_pagamento ||--o{ pedidos : "regula faturamento"

    vendedores {
        uuid id PK
        string codigo_vendedor UK
        string nome
        string email UK
        boolean ativo
    }

    clientes {
        bigint id PK
        string cpf_cnpj UK
        string nome
        string cidade
        string uf
        numeric limite_credito
        uuid vendedor_id FK
    }

    produtos {
        bigint id PK
        string sku UK
        string nome
        numeric preco_tabela
        numeric estoque_disponivel
    }

    condicoes_pagamento {
        int id PK
        string codigo UK
        string descricao
        int parcelas
    }

    pedidos {
        bigint id PK
        string codigo_pedido UK
        uuid vendedor_id FK
        bigint cliente_id FK
        numeric total
        string forma_pagamento
        string status_sync
        string status_fiscal
        timestamp data_criacao
    }

    pedido_itens {
        bigint id PK
        bigint pedido_id FK
        string sku
        numeric quantidade
        numeric preco_unitario
        numeric subtotal
    }
```
"""
    er_file.write_text(er_content, encoding="utf-8")

    print(f"✅ Diagramas visuais em Mermaid gerados em: {DIAGRAMS_DIR}")

if __name__ == "__main__":
    generate_diagrams()
