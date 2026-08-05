-- ==============================================================================
-- DDL DE SCHEMA SUPABASE POSTGRESQL COM ROW LEVEL SECURITY (RLS)
-- PROJETO: AMPLA VENDAS PRO (INFOINTRA) - AMPLA INFORMÁTICA
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. TABELA DE VENDEDORES / PERFIS (Vinculada ao auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vendedores (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    codigo_vendedor VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    cargo VARCHAR(50) DEFAULT 'Vendedor de Campo',
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.vendedores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Vendedores visualizam o proprio perfil ou admins"
    ON public.vendedores FOR SELECT
    USING (auth.uid() = id);

-- ------------------------------------------------------------------------------
-- 2. TABELA DE CLIENTES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clientes (
    id BIGSERIAL PRIMARY KEY,
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

CREATE POLICY "Vendedores acessam apenas seus clientes da carteira"
    ON public.clientes FOR ALL
    USING (vendedor_id = auth.uid() OR vendedor_id IS NULL);

-- ------------------------------------------------------------------------------
-- 3. TABELA DE PRODUTOS / CATÁLOGO ERP
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.produtos (
    id BIGSERIAL PRIMARY KEY,
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

CREATE POLICY "Catálogo de produtos é legível por todos os usuários autenticados"
    ON public.produtos FOR SELECT
    TO authenticated
    USING (TRUE);

-- ------------------------------------------------------------------------------
-- 4. TABELA DE CONDIÇÕES DE PAGAMENTO
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

CREATE POLICY "Condições de pagamento visíveis a todos autenticados"
    ON public.condicoes_pagamento FOR SELECT
    TO authenticated
    USING (TRUE);

-- ------------------------------------------------------------------------------
-- 5. TABELA DE PEDIDOS DE VENDA (CABEÇALHO)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedidos (
    id BIGSERIAL PRIMARY KEY,
    codigo_pedido VARCHAR(50) NOT NULL UNIQUE,
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

CREATE POLICY "Vendedor cria e visualiza apenas seus proprios pedidos"
    ON public.pedidos FOR ALL
    USING (vendedor_id = auth.uid())
    WITH CHECK (vendedor_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 6. TABELA DE ITENS DO PEDIDO (DETALHE RELACIONAL)
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

CREATE POLICY "Acesso aos itens herdado da permissão do pedido pai"
    ON public.pedido_itens FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.pedidos p 
            WHERE p.id = public.pedido_itens.pedido_id 
            AND p.vendedor_id = auth.uid()
        )
    );

-- ------------------------------------------------------------------------------
-- INDEXES DE PERFORMANCE PARA SINCRONIZAÇÃO E BUSCA
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedidos_vendedor ON public.pedidos(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON public.pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_status_sync ON public.pedidos(status_sync);
CREATE INDEX IF NOT EXISTS idx_pedido_itens_pedido ON public.pedido_itens(pedido_id);
