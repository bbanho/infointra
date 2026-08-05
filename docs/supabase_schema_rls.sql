-- ==============================================================================
-- DDL DE SCHEMA SUPABASE POSTGRESQL COM IAM MULTI-UNIDADE E ROW LEVEL SECURITY (RLS)
-- PROJETO: AMPLA VENDAS PRO (INFOINTRA) - AMPLA INFORMÁTICA
-- REQUISITO: IAM (Identity & Access Management) com múltiplos perfis e unidades por login
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. UNIDADES ORGANIZACIONAIS (Filiais / Depósitos / Regiões)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.unidades (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE, -- Ex: 'SP-FARIALIMA', 'RJ-CENTRO', 'RS-SUL'
    nome VARCHAR(150) NOT NULL,
    cnpj VARCHAR(20),
    uf VARCHAR(2) NOT NULL,
    cidade VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.unidades ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2. PERFIS DE ACESSO IAM (Roles & Permissões RBAC)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.perfis_acesso (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE, -- Ex: 'ADMIN_GLOBAL', 'GERENTE_UNIDADE', 'VENDEDOR_CAMPO', 'AUDITOR_FISCAL'
    nome VARCHAR(100) NOT NULL,
    nivel_hierarquico INT DEFAULT 10, -- 100=Admin, 50=Gerente, 10=Vendedor
    permissoes JSONB NOT NULL DEFAULT '{}', -- Ex: {"pedidos": ["create","read","update","export"], "desconto_maximo": 15.0}
    ativo BOOLEAN DEFAULT TRUE
);

ALTER TABLE public.perfis_acesso ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 3. MAPEAMENTO MULTI-PERFIL E MULTI-UNIDADE POR USUÁRIO (Single Login, Multi-Context)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuario_perfis_unidades (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    unidade_id INT NOT NULL REFERENCES public.unidades(id) ON DELETE CASCADE,
    perfil_id INT NOT NULL REFERENCES public.perfis_acesso(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT FALSE,
    criado_em TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uk_usuario_unidade_perfil UNIQUE(usuario_id, unidade_id, perfil_id)
);

ALTER TABLE public.usuario_perfis_unidades ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 4. TABELA DE VENDEDORES / USUÁRIOS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vendedores (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    codigo_vendedor VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    cargo VARCHAR(50) DEFAULT 'Vendedor de Campo',
    unidade_padrao_id INT REFERENCES public.unidades(id),
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.vendedores ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 5. FUNÇÕES HELPER IAM PARA VALIDAÇÃO EM RLS
-- ------------------------------------------------------------------------------

-- Função para obter todas as unidades autorizadas para o usuário logado
CREATE OR REPLACE FUNCTION public.get_user_unidade_ids(p_user_id UUID)
RETURNS INT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT DISTINCT unidade_id 
        FROM public.usuario_perfis_unidades 
        WHERE usuario_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para verificar se o usuário é Admin Global
CREATE OR REPLACE FUNCTION public.is_admin_global(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.usuario_perfis_unidades upu
        JOIN public.perfis_acesso pa ON pa.id = upu.perfil_id
        WHERE upu.usuario_id = p_user_id AND pa.codigo = 'ADMIN_GLOBAL'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 6. TABELA DE CLIENTES (COM VÍNCULO DE UNIDADE)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clientes (
    id BIGSERIAL PRIMARY KEY,
    unidade_id INT REFERENCES public.unidades(id),
    cpf_cnpj VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(200) NOT NULL,
    nome_fantasia VARCHAR(200),
    email VARCHAR(150),
    telefone VARCHAR(30),
    cidade VARCHAR(100) NOT NULL,
    uf VARCHAR(2) NOT NULL,
    endereco VARCHAR(255),
    limite_credito NUMERIC(12,2) DEFAULT 0.00,
    vendedor_id UUID REFERENCES public.vendedores(id),
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "IAM Clientes: Admin Global vindo de qualquer unidade"
    ON public.clientes FOR ALL
    USING (public.is_admin_global(auth.uid()));

CREATE POLICY "IAM Clientes: Acesso por Unidade ou Carteira do Vendedor"
    ON public.clientes FOR ALL
    USING (
        unidade_id = ANY(public.get_user_unidade_ids(auth.uid()))
        OR vendedor_id = auth.uid()
    );

-- ------------------------------------------------------------------------------
-- 7. TABELA DE PRODUTOS / CATÁLOGO
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.produtos (
    id BIGSERIAL PRIMARY KEY,
    unidade_id INT REFERENCES public.unidades(id),
    sku VARCHAR(50) NOT NULL UNIQUE,
    nome VARCHAR(200) NOT NULL,
    descricao TEXT,
    categoria VARCHAR(100),
    unidade VARCHAR(10) DEFAULT 'UN',
    preco_tabela NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    custo NUMERIC(12,2) DEFAULT 0.00,
    estoque_disponivel NUMERIC(10,2) DEFAULT 0.00,
    ativo BOOLEAN DEFAULT TRUE,
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "IAM Produtos: Leitura para usuários autenticados da unidade"
    ON public.produtos FOR SELECT
    TO authenticated
    USING (
        unidade_id IS NULL 
        OR unidade_id = ANY(public.get_user_unidade_ids(auth.uid()))
        OR public.is_admin_global(auth.uid())
    );

-- ------------------------------------------------------------------------------
-- 8. TABELA DE CONDIÇÕES DE PAGAMENTO
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.condicoes_pagamento (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    descricao VARCHAR(150) NOT NULL,
    parcelas INT DEFAULT 1,
    desconto_maximo_percentual NUMERIC(5,2) DEFAULT 0.00,
    ativo BOOLEAN DEFAULT TRUE
);

ALTER TABLE public.condicoes_pagamento ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Condições legíveis por autenticados"
    ON public.condicoes_pagamento FOR SELECT
    TO authenticated USING (TRUE);

-- ------------------------------------------------------------------------------
-- 9. TABELA DE PEDIDOS DE VENDA (COM UNIDADE ORGANIZACIONAL)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedidos (
    id BIGSERIAL PRIMARY KEY,
    codigo_pedido VARCHAR(50) NOT NULL UNIQUE,
    unidade_id INT NOT NULL REFERENCES public.unidades(id),
    vendedor_id UUID NOT NULL REFERENCES public.vendedores(id),
    cliente_id BIGINT NOT NULL REFERENCES public.clientes(id),
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    desconto_geral_valor NUMERIC(12,2) DEFAULT 0.00,
    total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    forma_pagamento VARCHAR(50) NOT NULL,
    parcelas INT DEFAULT 1,
    condicao_pagamento VARCHAR(150),
    observacoes TEXT,
    assinatura_digital_url TEXT,
    status_sync VARCHAR(30) DEFAULT 'sincronizado',
    status_fiscal VARCHAR(30) DEFAULT 'PENDENTE',
    chave_nfe VARCHAR(50),
    protocolo_nfe VARCHAR(50),
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "IAM Pedidos: Admin Global acessa todos os pedidos"
    ON public.pedidos FOR ALL
    USING (public.is_admin_global(auth.uid()));

CREATE POLICY "IAM Pedidos: Vendedor/Gerente acessa pedidos de sua unidade autorizada"
    ON public.pedidos FOR ALL
    USING (
        unidade_id = ANY(public.get_user_unidade_ids(auth.uid()))
        AND (vendedor_id = auth.uid() OR public.is_admin_global(auth.uid()))
    )
    WITH CHECK (
        unidade_id = ANY(public.get_user_unidade_ids(auth.uid()))
        AND vendedor_id = auth.uid()
    );

-- ------------------------------------------------------------------------------
-- 10. ITENS DO PEDIDO
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedido_itens (
    id BIGSERIAL PRIMARY KEY,
    pedido_id BIGINT NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
    produto_id BIGINT REFERENCES public.produtos(id),
    sku VARCHAR(50) NOT NULL,
    nome_produto VARCHAR(200) NOT NULL,
    unidade VARCHAR(10) DEFAULT 'UN',
    quantidade NUMERIC(10,2) NOT NULL,
    preco_unitario NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    observacao TEXT
);

ALTER TABLE public.pedido_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "IAM Pedido Itens: Herdado do pedido pai autorizado"
    ON public.pedido_itens FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.pedidos p 
            WHERE p.id = public.pedido_itens.pedido_id 
            AND (
                p.unidade_id = ANY(public.get_user_unidade_ids(auth.uid()))
                OR public.is_admin_global(auth.uid())
            )
        )
    );

-- ------------------------------------------------------------------------------
-- DADOS SEED DE EXEMPLO (UNIDADES E PERFIS IAM)
-- ------------------------------------------------------------------------------
INSERT INTO public.unidades (codigo, nome, cnpj, uf, cidade) VALUES
('SP-FARIALIMA', 'Unidade São Paulo - Faria Lima', '18.442.981/0001-92', 'SP', 'São Paulo'),
('RJ-CENTRO', 'Unidade Rio de Janeiro - Centro', '18.442.981/0002-73', 'RJ', 'Rio de Janeiro'),
('RS-PORTOALEGRE', 'Unidade Rio Grande do Sul - POA', '18.442.981/0003-54', 'RS', 'Porto Alegre')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO public.perfis_acesso (codigo, nome, nivel_hierarquico, permissoes) VALUES
('ADMIN_GLOBAL', 'Administrador Global', 100, '{"todas_unidades": true, "pedidos": ["create","read","update","delete","export"], "desconto_maximo": 100.0}'),
('GERENTE_UNIDADE', 'Gerente de Unidade', 50, '{"todas_unidades": false, "pedidos": ["create","read","update","export"], "desconto_maximo": 30.0}'),
('VENDEDOR_CAMPO', 'Vendedor de Campo', 10, '{"todas_unidades": false, "pedidos": ["create","read","export"], "desconto_maximo": 15.0}'),
('AUDITOR_FISCAL', 'Auditor Fiscal / Contábil', 20, '{"todas_unidades": true, "pedidos": ["read","export"], "desconto_maximo": 0.0}')
ON CONFLICT (codigo) DO NOTHING;

-- ------------------------------------------------------------------------------
-- INDEXES DE PERFORMANCE IAM
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_upu_usuario ON public.usuario_perfis_unidades(usuario_id);
CREATE INDEX IF NOT EXISTS idx_upu_unidade ON public.usuario_perfis_unidades(unidade_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_unidade ON public.pedidos(unidade_id);
CREATE INDEX IF NOT EXISTS idx_clientes_unidade ON public.clientes(unidade_id);
