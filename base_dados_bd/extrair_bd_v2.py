"""Extract party, municipal-result, census-tract and boundary data from Base dos Dados (BigQuery).

Usage:
    python extrair_bd_v2.py --project <gcp_billing_project> --dry-run   # estimate bytes only
    python extrair_bd_v2.py --project <gcp_billing_project> --run       # run the queries and save parquet files

Tables:
  partidos_coligacoes : parties and coalition composition (RJ; paper municipalities and state level), 2006-2024
  resultados_cand_mun : results by candidate and municipality (mayor and council), 2004-2024 (winners and the
                        incumbent mayor's party; 2004 is needed for the 2008 incumbent)
  setores_2010        : 2010 census tracts (population V002, households V001) with WKT geometry
  setores_2022        : 2022 census tracts (persons, households) with WKT geometry
  municipios_geo      : municipal boundaries (geobr) in WKT
Output in $AFE_DADOS/basedosdados_v2. Same credentials as extrair_bd.py. No personal data is selected.
"""
import argparse, os, hashlib, json, subprocess, sys, time
from pathlib import Path

from google.cloud import bigquery

OUT_DIR = Path(os.environ.get("AFE_DADOS", "data")) / "basedosdados_v2"

MUN_TSE = ["58041", "58157", "58335", "58378", "58394", "58149", "58491", "58530", "58467", "58637",
           "58653", "58696", "58718", "58777", "58122", "58858", "60011", "58424", "58971", "59013"]
MUN_IBGE = ["3300456", "3300803", "3301702", "3301900", "3302007", "3302270", "3302502", "3302700",
            "3302858", "3303203", "3303302", "3303500", "3303609", "3303906", "3304144", "3304300",
            "3304557", "3305554", "3304904", "3305109"]

def lst(xs):
    return ", ".join(f"'{x}'" for x in xs)

QUERIES = {
    "partidos_coligacoes": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, id_municipio, id_municipio_tse, cargo, numero, sigla, tipo_agremiacao,
               sequencial_coligacao, nome_coligacao, composicao_coligacao, numero_federacao, sigla_federacao,
               composicao_federacao, situacao_legenda
        FROM `basedosdados.br_tse_eleicoes.partidos`
        WHERE sigla_uf = 'RJ' AND ano BETWEEN 2006 AND 2024
          AND (id_municipio_tse IN ({lst(MUN_TSE)}) OR id_municipio_tse IS NULL OR id_municipio_tse = '')""",
    "resultados_cand_mun": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, id_municipio, id_municipio_tse, cargo, numero_partido, sigla_partido,
               sequencial_candidato, numero_candidato, resultado, votos
        FROM `basedosdados.br_tse_eleicoes.resultados_candidato_municipio`
        WHERE sigla_uf = 'RJ' AND ano IN (2004, 2008, 2012, 2016, 2020, 2024)
          AND id_municipio_tse IN ({lst(MUN_TSE)}) AND cargo IN ('prefeito', 'vereador')""",
    "setores_2010": f"""
        SELECT g.id_setor_censitario, g.id_municipio, g.zona, b.v001 AS domicilios, b.v002 AS populacao,
               ST_ASTEXT(g.geometria) AS wkt
        FROM `basedosdados.br_geobr_mapas.setor_censitario_2010` g
        LEFT JOIN `basedosdados.br_ibge_censo_demografico.setor_censitario_basico_2010` b
          ON b.id_setor_censitario = g.id_setor_censitario AND b.sigla_uf = 'RJ'
        WHERE g.sigla_uf = 'RJ' AND g.id_municipio IN ({lst(MUN_IBGE)})""",
    "setores_2022": f"""
        SELECT id_setor_censitario, id_municipio, pessoas AS populacao, domicilios, ST_ASTEXT(geometria) AS wkt
        FROM `basedosdados.br_ibge_censo_2022.setor_censitario`
        WHERE id_municipio IN ({lst(MUN_IBGE)})""",
    "municipios_geo": f"""
        SELECT id_municipio, ST_ASTEXT(geometria) AS wkt
        FROM `basedosdados.br_geobr_mapas.municipio`
        WHERE id_municipio IN ({lst(MUN_IBGE)})""",
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
            print(f"{t:25s} {b/1e9:8.3f} GB (estimativa)"); continue
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
