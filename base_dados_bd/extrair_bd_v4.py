"""Extract the 2010 census tract socioeconomic profile from Base dos Dados (BigQuery).

Usage:
    python extrair_bd_v4.py --project <gcp_billing_project> --schema    # metadata only (INFORMATION_SCHEMA)
    python extrair_bd_v4.py --project <gcp_billing_project> --dry-run   # estimate bytes only
    python extrair_bd_v4.py --project <gcp_billing_project> --run       # run the queries and save parquet files

Table:
  setores_2010_perfil : for each 2010 census tract in the 20 paper municipalities, the variables of the census
                        Basico file (households, residents, mean income of household heads) and the tract's situation
                        and type. No geometry: id_setor_censitario matches setores_2010.parquet.
Output in $AFE_DADOS/basedosdados_v4. Same credentials as extrair_bd.py.
"""
import argparse, os, hashlib, json, subprocess, sys, time
from pathlib import Path

from google.cloud import bigquery

OUT_DIR = Path(os.environ.get("AFE_DADOS", "data")) / "basedosdados_v4"
TABELA = "setor_censitario_basico_2010"

MUN_IBGE = ["3300456", "3300803", "3301702", "3301900", "3302007", "3302270", "3302502", "3302700",
            "3302858", "3303203", "3303302", "3303500", "3303609", "3303906", "3304144", "3304300",
            "3304557", "3305554", "3304904", "3305109"]


def lst(xs):
    return ", ".join(f"'{x}'" for x in xs)


QUERIES = {
    "setores_2010_perfil": f"""
        SELECT id_setor_censitario, v001 AS domicilios, v002 AS moradores, v003 AS moradores_por_domicilio,
               v005 AS renda_resp_media, v007 AS renda_resp_media_com_rend, v009 AS renda_pessoa_media, v011 AS renda_pessoa_media_com_rend
        FROM `basedosdados.br_ibge_censo_demografico.{TABELA}`
        WHERE sigla_uf = 'RJ' AND SUBSTR(id_setor_censitario, 1, 7) IN ({lst(MUN_IBGE)})""",
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
    g.add_argument("--schema", action="store_true"); g.add_argument("--dry-run", action="store_true"); g.add_argument("--run", action="store_true")
    a = ap.parse_args()
    client = bigquery.Client(project=a.project, credentials=credentials())
    if a.schema:
        q = ("SELECT table_name FROM `basedosdados.br_ibge_censo_demografico.INFORMATION_SCHEMA.TABLES` "
             "WHERE table_name LIKE 'setor_censitario%2010' ORDER BY table_name")
        print("tabelas de setor de 2010:", ", ".join(r["table_name"] for r in client.query(q).result()))
        q = ("SELECT column_name, data_type, description FROM `basedosdados.br_ibge_censo_demografico.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS` "
             f"WHERE table_name = '{TABELA}' ORDER BY column_name")
        for r in client.query(q).result():
            print(f"  {r['column_name']:24s} {r['data_type']:10s} {(r['description'] or '')[:150]}")
        return 0
    manifest, total = [], 0
    if a.run:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
    for t, sql in QUERIES.items():
        out = OUT_DIR / f"{t}.parquet"
        if a.run and out.exists():
            print(f"{t:25s} já existe, pulando"); continue
        job = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=a.dry_run, use_query_cache=False))
        if a.dry_run:
            b = job.total_bytes_processed or 0; total += b
            print(f"{t:25s} {b/1e9:8.3f} GB (estimativa)"); continue
        df = job.result().to_dataframe(create_bqstorage_client=True)
        df.to_parquet(out, index=False)
        manifest.append(dict(tabela=t, linhas=len(df), colunas=list(df.columns), arquivo=str(out), sha256=sha256(out), job_id=job.job_id,
                             bytes_processados=job.total_bytes_processed, bytes_cobrados=job.total_bytes_billed,
                             extraido_em=time.strftime("%Y-%m-%d %H:%M:%S")))
        total += job.total_bytes_billed or 0
        print(f"{t:25s} {len(df):>9,d} linhas  cobrado {(job.total_bytes_billed or 0)/1e9:.3f} GB")
    print(f"\nTOTAL {'estimado' if a.dry_run else 'cobrado'}: {total/1e9:.2f} GB")
    if a.run and manifest:
        mf = OUT_DIR / f"manifesto_{time.strftime('%Y%m%d_%H%M%S')}.json"
        mf.write_text(json.dumps(manifest, indent=1, default=str), encoding="utf-8"); print("manifesto:", mf)
    return 0


if __name__ == "__main__":
    sys.exit(main())
