#!/usr/bin/env python3
"""
Script Periférico de Simulação de Payloads JSON & Lotes XML ERP
Projeto: Ampla Vendas Pro (infointra) - Ampla Informática
Finalidade: Gerar e validar amostras de intercâmbio de dados para revisão visual dos arquitetos parceiros.
"""

import json
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
DOCS_DIR = REPO_ROOT / "docs"

def generate_sample_payloads():
    now_str = datetime.now().isoformat()
    today_date = datetime.now().strftime("%Y-%m-%d")

    # Sample JSON Payload for Supabase REST API
    sample_json = {
        "pedido": {
            "codigo_pedido": "PED-2026-0984",
            "vendedor_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3d0001",
            "vendedor_nome": "Bruno Silva (Vendedor de Campo)",
            "cliente_id": 104,
            "cliente_nome": "Distribuidora de Alimentos Sul Ltda",
            "cliente_cpf_cnpj": "18.442.981/0001-92",
            "subtotal": 12500.00,
            "desconto_geral_valor": 500.00,
            "total": 12000.00,
            "forma_pagamento": "BOLETO_30_60_90",
            "parcelas": 3,
            "condicao_pagamento": "Boleto Faturado ERP (3x sem juros)",
            "observacoes": "Entrega agendada para o turno da manhã. Cliente solicitou nota espelho impressa.",
            "status_sync": "pendente_sync",
            "status_fiscal": "PENDENTE",
            "data_criacao": now_str
        },
        "itens": [
            {
                "sku": "HW-SRV-R750",
                "nome": "Servidor Dell PowerEdge R750 Xeon Silver",
                "quantidade": 1,
                "preco_unitario": 8500.00,
                "subtotal": 8500.00
            },
            {
                "sku": "SW-LIC-ERP12",
                "nome": "Licença ERP Cloud PRO - Assinatura Anual",
                "quantidade": 1,
                "preco_unitario": 4000.00,
                "subtotal": 4000.00
            }
        ]
    }

    json_file = DOCS_DIR / "SAMPLE_PAYLOAD_REST.json"
    json_file.write_text(json.dumps(sample_json, indent=2, ensure_ascii=False), encoding="utf-8")

    # Sample XML ERP Integration Batch
    xml_items = ""
    for idx, item in enumerate(sample_json["itens"], 1):
        xml_items += f"""      <Item nItem="{idx}">
        <SKU>{item['sku']}</SKU>
        <Descricao>{item['nome']}</Descricao>
        <Quantidade>{item['quantidade']}</Quantidade>
        <ValorUnitario>{item['preco_unitario']:.2f}</ValorUnitario>
        <ValorTotal>{item['subtotal']:.2f}</ValorTotal>
      </Item>\n"""

    sample_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<LoteIntegracaoERP xmlns="http://www.amplavendas.eng.br/schema/erp/v2" dataHora="{now_str}" qtdPedidos="1">
  <IdentificacaoOrigem>
    <Sistema>Ampla Vendas Pro - PWA Offline-First</Sistema>
    <Versao>2.4.0</Versao>
    <Representante>{sample_json['pedido']['vendedor_nome']}</Representante>
  </IdentificacaoOrigem>
  <Pedidos>
    <Pedido id="{sample_json['pedido']['codigo_pedido']}">
      <Cliente>
        <CPF_CNPJ>{sample_json['pedido']['cliente_cpf_cnpj']}</CPF_CNPJ>
        <RazaoSocial>{sample_json['pedido']['cliente_nome']}</RazaoSocial>
      </Cliente>
      <CondicaoPagamento>{sample_json['pedido']['condicao_pagamento']}</CondicaoPagamento>
      <ValorTotal>{sample_json['pedido']['total']:.2f}</ValorTotal>
      <Itens>
{xml_items}      </Itens>
    </Pedido>
  </Pedidos>
</LoteIntegracaoERP>"""

    xml_file = DOCS_DIR / f"Lote_Pedidos_ERP_{today_date}.xml"
    xml_file.write_text(sample_xml, encoding="utf-8")

    print(f"✅ Payloads de exemplo gerados em:")
    print(f"   - JSON REST: {json_file}")
    print(f"   - XML ERP:  {xml_file}")

if __name__ == "__main__":
    generate_sample_payloads()
