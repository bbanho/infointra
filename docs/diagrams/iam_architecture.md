# 🛡️ Arquitetura IAM (Identity & Access Management) - Ampla Vendas Pro

## Visão Geral do IAM Multi-Perfil & Multi-Unidade

* **Single Identity (Único Login):** O usuário possui uma única credencial de autenticação (`auth.users.id`).
* **Multi-Unidade & Multi-Perfil:** A mesma identidade pode possuir permissões atribuídas a múltiplas unidades organizacionais (ex: `SP-FARIALIMA`, `RJ-CENTRO`, `RS-PORTOALEGRE`) com perfis distintos (`ADMIN_GLOBAL`, `GERENTE_UNIDADE`, `VENDEDOR_CAMPO`).
* **Seleção Contextual (Padrão + Optativo):** No login, o usuário assume automaticamente sua **Unidade/Perfil Padrão** (`is_default = true`). Caso possua múltiplos acessos, a interface permite alterar o contexto de trabalho ativamente sem necessidade de novo login.

---

## Diagrama de Entidades IAM (RBAC + Tenancy)

```mermaid
erDiagram
    auth_users ||--|| usuarios_vendedores : "1 : 1 Credencial"
    usuarios_vendedores ||--o{ usuario_perfis_unidades : "possui acessos"
    unidades ||--o{ usuario_perfis_unidades : "unidade autorizada"
    perfis_acesso ||--o{ usuario_perfis_unidades : "papel atribuido"
    unidades ||--o{ pedidos : "escopo da venda"
    unidades ||--o{ clientes : "carteira da filial"

    usuarios_vendedores {
        uuid id PK
        string email UK
        string nome
        int unidade_padrao_id FK
    }

    unidades {
        int id PK
        string codigo UK
        string nome
        string uf
    }

    perfis_acesso {
        int id PK
        string codigo UK
        int nivel_hierarquico
        jsonb permissoes
    }

    usuario_perfis_unidades {
        bigint id PK
        uuid usuario_id FK
        int unidade_id FK
        int perfil_id FK
        boolean is_default
    }
```

---

## Fluxo de Autenticação e Seleção de Contexto no Login

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as Usuário (Login)
    participant UI as Interface PWA
    participant Auth as Supabase Auth (JWT)
    participant IAM as PostgreSQL RLS (usuario_perfis_unidades)

    Usuario->>UI: Digita E-mail e Senha
    UI->>Auth: POST /token (grant_type=password)
    Auth-->>UI: Retorna JWT Session (auth.uid)
    
    UI->>IAM: Consulta acessos (get_user_unidade_ids & usuario_perfis_unidades)
    IAM-->>UI: Retorna lista de Unidades e Perfis autorizados

    alt Usuário tem 1 único perfil/unidade
        UI->>UI: Carrega ambiente com o perfil atribuído
    else Usuário tem Múltiplos Perfis/Unidades
        UI->>UI: Carrega Unidade Padrão (is_default=true)
        UI->>Usuario: Exibe seletor de contexto no topo (Permite trocar para RJ, RS, etc)
    end
```
