#!/usr/bin/env python3
"""
Script Periférico de Análise de Bundle & Código JS/CSS
Projeto: Ampla Vendas Pro (infointra) - Ampla Informática
Finalidade: Gerar relatório visual de saúde de bundle, componentes e dependências para revisão de arquitetos.
"""

import os
import re
import json
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
DOCS_DIR = REPO_ROOT / "docs"

def analyze_assets():
    if not ASSETS_DIR.exists():
        print("❌ Diretório assets não encontrado.")
        return

    js_files = list(ASSETS_DIR.glob("*.js"))
    css_files = list(ASSETS_DIR.glob("*.css"))

    report = []
    report.append("# 📊 Relatório de Análise Visual de Bundle & Código")
    report.append(f"**Data da Análise:** {os.popen('date').read().strip()}")
    report.append("\n## 1. Métricas Globais de Distribuição (Build Assets)\n")
    report.append("| Arquivo | Tipo | Tamanho (Bytes) | Tamanho (KB) | Status |")
    report.append("| :--- | :--- | :--- | :--- | :--- |")

    total_bytes = 0
    for file in js_files + css_files:
        size = file.stat().st_size
        total_bytes += size
        ext = file.suffix.upper()[1:]
        status = "⚠️ Grande (>500KB)" if size > 500000 else "✅ Adequado"
        report.append(f"| `{file.name}` | {ext} | {size:,} B | {size / 1024:.2f} KB | {status} |")

    report.append(f"\n**Tamanho Total do App:** `{total_bytes / 1024 / 1024:.2f} MB` ({total_bytes:,} Bytes)\n")

    # Inspeção de Padrões Arquitetônicos no JS
    if js_files:
        js_path = js_files[0]
        content = js_path.read_text(encoding="utf-8", errors="ignore")

        report.append("## 2. Auditoria Estrutural de Componentes e Dependências Embutidas\n")
        
        features = {
            "Supabase Auth & GoTrue": r"supabase\.auth|gotrue",
            "IndexedDB / Storage": r"IndexedDB|localStorage",
            "Simulação Fiscal (SEFAZ / NFC-e / NF-e)": r"CUPOM_EMITIDO|NFE_EMITIDA|DANFE|SAT",
            "Assinatura Digital Base64": r"assinaturaBase64",
            "Exportação XML Lote ERP": r"LoteIntegracaoERP",
            "Exportação CSV / Excel": r"application/xml|text/csv",
            "TailwindCSS Classes": r"bg-indigo-600|flex flex-col"
        }

        report.append("| Funcionalidade / Padrão | Ocorrências Identificadas | Avaliação Arquitetônica |")
        report.append("| :--- | :--- | :--- |")

        for feat, regex in features.items():
            matches = len(re.findall(regex, content, re.IGNORECASE))
            eval_status = "✅ Presente" if matches > 0 else "❌ Não Detectado"
            report.append(f"| {feat} | {matches} trechos | {eval_status} |")

    # Salva relatório em docs
    report_file = DOCS_DIR / "ANALYSIS_BUNDLE_REPORT.md"
    report_file.parent.mkdir(parents=True, exist_ok=True)
    report_file.write_text("\n".join(report), encoding="utf-8")
    
    print(f"✅ Relatório gerado com sucesso em: {report_file}")
    print("\n--- RESUMO VISUAL NO TERMINAL ---")
    print("\n".join(report[:15]))

if __name__ == "__main__":
    analyze_assets()
