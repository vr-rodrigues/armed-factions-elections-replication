"""Extract voter-profile, campaign-revenue and 2004 election data from Base dos Dados (BigQuery).

Usage:
    python extrair_bd_v3.py --project <gcp_billing_project> --dry-run   # estimate bytes only (no cost)
    python extrair_bd_v3.py --project <gcp_billing_project> --run       # run the queries and save parquet files

Tables:
  perfil_eleitorado_secao_agregado : registered voters by section and year, with counts by sex, age and schooling
                                     (aggregated in BigQuery; no individual records), 2008-2024
  receitas_candidato_agregado      : campaign revenue by candidate, total and financial, mayor and council
  *_2004                           : the 2004 municipal election by section (same queries as extrair_bd.py)
Output in $AFE_DADOS/basedosdados_v3. Same credentials as extrair_bd.py. No personal data is selected.
"""
import argparse, os, hashlib, json, subprocess, sys, time
from pathlib import Path

from google.cloud import bigquery

OUT_DIR = Path(os.environ.get("AFE_DADOS", "data")) / "basedosdados_v3"

MUN_TSE = ["58041", "58157", "58335", "58378", "58394", "58149", "58491", "58530", "58467", "58637",
           "58653", "58696", "58718", "58777", "58122", "58858", "60011", "58424", "58971", "59013"]

def lst(xs):
    return ", ".join(f"'{x}'" for x in xs)

QUERIES = {
    # agregado por seção e ano no BigQuery (códigos do TSE: gênero 2 = masculino, 4 = feminino, 0 = não informado;
    # faixa etária 1600 = 16 anos ... 2124 = 21-24, ..., 9999/-3 = inválida; instrução 1 = analfabeto, 2 = lê e escreve,
    # 3 = fundamental incompleto, 4 = fundamental completo, 5 = médio incompleto, 6 = médio completo,
    # 7 = superior incompleto, 8 = superior completo, 0 = não informado)
    "perfil_eleitorado_secao_agregado": f"""
        SELECT ano, id_municipio_tse, zona, secao,
               SUM(eleitores) AS eleitores,
               SUM(IF(genero IN ('2', '4'), eleitores, 0)) AS n_genero,
               SUM(IF(genero = '4', eleitores, 0)) AS n_fem,
               SUM(IF(SAFE_CAST(grupo_idade AS INT64) BETWEEN 1600 AND 9599, eleitores, 0)) AS n_idade,
               SUM(IF(SAFE_CAST(grupo_idade AS INT64) BETWEEN 1600 AND 2124, eleitores, 0)) AS n_ate24,
               SUM(IF(SAFE_CAST(grupo_idade AS INT64) BETWEEN 6064 AND 9599, eleitores, 0)) AS n_60mais,
               SUM(IF(instrucao IN ('1','2','3','4','5','6','7','8'), eleitores, 0)) AS n_instrucao,
               SUM(IF(instrucao IN ('1','2','3','4'), eleitores, 0)) AS n_ate_fund,
               SUM(IF(instrucao IN ('7','8'), eleitores, 0)) AS n_superior
        FROM `basedosdados.br_tse_eleicoes.perfil_eleitorado_secao`
        WHERE sigla_uf = 'RJ' AND ano BETWEEN 2008 AND 2024 AND id_municipio_tse IN ({lst(MUN_TSE)})
        GROUP BY 1, 2, 3, 4""",
    # receita por candidato, total e financeira (sem doações estimáveis, marcadas em especie_receita em 2008 e
    # em natureza_receita em 2012-2024); prefeito e vereador, eleições municipais
    "receitas_candidato_agregado": f"""
        SELECT ano, id_municipio_tse, cargo, sequencial_candidato, numero_candidato,
               SUM(valor_receita) AS receita_total,
               SUM(IF(COALESCE(especie_receita, '') = 'estimado' OR COALESCE(natureza_receita, '') IN ('estimado', 'estimavel'),
                      0, valor_receita)) AS receita_financeira,
               COUNT(*) AS n_registros
        FROM `basedosdados.br_tse_eleicoes.receitas_candidato`
        WHERE sigla_uf = 'RJ' AND ano IN (2008, 2012, 2016, 2020, 2024) AND cargo IN ('prefeito', 'vereador')
          AND id_municipio_tse IN ({lst(MUN_TSE)})
        GROUP BY 1, 2, 3, 4, 5""",
    # eleição municipal de 2004 por seção (mesmas consultas do extrair_bd.py)
    "resultados_candidato_secao_2004": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, data_eleicao, id_municipio, id_municipio_tse, zona, secao,
               cargo, numero_partido, sigla_partido, sequencial_candidato, numero_candidato, votos
        FROM `basedosdados.br_tse_eleicoes.resultados_candidato_secao`
        WHERE sigla_uf = 'RJ' AND ano = 2004 AND id_municipio_tse IN ({lst(MUN_TSE)}) AND cargo IN ('prefeito', 'vereador')""",
    "detalhes_votacao_secao_2004": f"""
        SELECT * EXCEPT(sigla_uf)
        FROM `basedosdados.br_tse_eleicoes.detalhes_votacao_secao`
        WHERE sigla_uf = 'RJ' AND ano = 2004 AND id_municipio_tse IN ({lst(MUN_TSE)})""",
    "resultados_partido_secao_2004": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, id_municipio, id_municipio_tse, zona, secao, cargo,
               numero_partido, sigla_partido, votos_nominais, votos_legenda
        FROM `basedosdados.br_tse_eleicoes.resultados_partido_secao`
        WHERE sigla_uf = 'RJ' AND ano = 2004 AND id_municipio_tse IN ({lst(MUN_TSE)})""",
}

def credentials():
    # Google Application Default Credentials: None lets the BigQuery client find them
    # (run `gcloud auth application-default login` once).
    return None

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true"); g.add_argument("--run", action="store_true")
    ap.add_argument("--tables", nargs="*", default=list(QUERIES))
    a = ap.parse_args()
    manifest, total = [], 0
    if a.run:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
    for t in a.tables:
        out = OUT_DIR / f"{t}.parquet"
        if a.run and out.exists():
            print(f"{t:25s} já existe, pulando"); manifest.append(dict(tabela=t, arquivo=str(out), sha256=sha256(out), retomado=True)); continue
        client = bigquery.Client(project=a.project, credentials=credentials())
        job = client.query(QUERIES[t], job_config=bigquery.QueryJobConfig(dry_run=a.dry_run, use_query_cache=False))
        if a.dry_run:
            b = job.total_bytes_processed or 0; total += b
            print(f"{t:25s} {b/1e9:8.3f} GB (estimativa)")
            print("  colunas:", [f.name for f in job.schema] if job.schema else "(não informado no dry run)"); continue
        df = job.result().to_dataframe(create_bqstorage_client=True)
        df.to_parquet(out, index=False)
        manifest.append(dict(tabela=t, linhas=len(df), arquivo=str(out), sha256=sha256(out), job_id=job.job_id,
                             bytes_processados=job.total_bytes_processed, bytes_cobrados=job.total_bytes_billed,
                             extraido_em=time.strftime("%Y-%m-%d %H:%M:%S")))
        total += job.total_bytes_billed or 0
        print(f"{t:25s} {len(df):>9,d} linhas  cobrado {(job.total_bytes_billed or 0)/1e9:.3f} GB")
    print(f"\nTOTAL {'estimado' if a.dry_run else 'cobrado'}: {total/1e9:.2f} GB")
    if a.run:
        mf = OUT_DIR / f"manifesto_{time.strftime('%Y%m%d_%H%M%S')}.json"
        mf.write_text(json.dumps(manifest, indent=1, default=str), encoding="utf-8"); print("manifesto:", mf)

if __name__ == "__main__":
    sys.exit(main())
