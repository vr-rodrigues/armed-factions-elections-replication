"""Extract TSE electoral data from Base dos Dados (BigQuery).

Usage:
    python extrair_bd.py --project <gcp_billing_project> --dry-run   # estimate bytes only (no cost)
    python extrair_bd.py --project <gcp_billing_project> --run       # run the queries and save parquet files

Scope: state of Rio de Janeiro, the 20 metropolitan municipalities used in the paper, elections 2006-2024.
Output: one parquet file per table and year in $AFE_DADOS/basedosdados_tse, plus a manifest with SHA-256, bytes
processed and row counts. Credentials: Google Application Default Credentials (gcloud auth application-default
login); queries are billed to the project given in --project.
"""
import argparse, hashlib, json, os, subprocess, sys, time
from pathlib import Path

from google.cloud import bigquery

OUT_DIR = Path(os.environ.get("AFE_DADOS", "data")) / "basedosdados_tse"

MUN_TSE = ["58041", "58157", "58335", "58378", "58394", "58149", "58491", "58530", "58467", "58637",
           "58653", "58696", "58718", "58777", "58122", "58858", "60011", "58424", "58971", "59013"]
MUN_IBGE = ["3300456", "3300803", "3301702", "3301900", "3302007", "3302270", "3302502", "3302700",
            "3302858", "3303203", "3303302", "3303500", "3303609", "3303906", "3304144", "3304300",
            "3304557", "3305554", "3304904", "3305109"]
ANOS = list(range(2006, 2025, 2))

def lst(xs):
    return ", ".join(f"'{x}'" for x in xs)

BD = "basedosdados.br_tse_eleicoes"
QUERIES = {
    # votos por candidato e seção (1º e 2º turno; filtramos o turno na construção)
    "resultados_candidato_secao": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, data_eleicao, id_municipio, id_municipio_tse, zona, secao,
               cargo, numero_partido, sigla_partido, sequencial_candidato, numero_candidato, votos
        FROM `{BD}.resultados_candidato_secao`
        WHERE sigla_uf = 'RJ' AND ano = @ano AND id_municipio_tse IN ({lst(MUN_TSE)})""",
    # aptos, comparecimento, brancos, nulos, legenda por seção, turno e cargo
    "detalhes_votacao_secao": f"""
        SELECT * EXCEPT(sigla_uf)
        FROM `{BD}.detalhes_votacao_secao`
        WHERE sigla_uf = 'RJ' AND ano = @ano AND id_municipio_tse IN ({lst(MUN_TSE)})""",
    # votos nominais e de legenda por partido e seção
    "resultados_partido_secao": f"""
        SELECT ano, turno, id_eleicao, tipo_eleicao, id_municipio, id_municipio_tse, zona, secao, cargo,
               numero_partido, sigla_partido, votos_nominais, votos_legenda
        FROM `{BD}.resultados_partido_secao`
        WHERE sigla_uf = 'RJ' AND ano = @ano AND id_municipio_tse IN ({lst(MUN_TSE)})""",
    # seção -> local de votação (número, nome, endereço, coordenadas)
    "perfil_eleitorado_local_votacao": f"""
        SELECT * EXCEPT(sigla_uf, telefone)
        FROM `{BD}.perfil_eleitorado_local_votacao`
        WHERE sigla_uf = 'RJ' AND ano = @ano AND id_municipio_tse IN ({lst(MUN_TSE)})""",
    # geocodificação de seções (inclui anos sem arquivo de locais do TSE)
    "local_secao": f"""
        SELECT id_municipio, zona, secao, ano,
               ST_Y(melhor_urbano) AS lat_melhor_urbano, ST_X(melhor_urbano) AS lon_melhor_urbano,
               ST_Y(tse_recente) AS lat_tse_recente, ST_X(tse_recente) AS lon_tse_recente,
               ST_Y(tse_distribuido) AS lat_tse_distribuido, ST_X(tse_distribuido) AS lon_tse_distribuido
        FROM `{BD}.local_secao`
        WHERE sigla_uf = 'RJ' AND ano = @ano AND id_municipio IN ({lst(MUN_IBGE)})""",
    # candidatos (RJ inteiro; tabela pequena). CPF, e-mail e título eleitoral ficam de fora.
    "candidatos": f"""
        SELECT ano, id_eleicao, tipo_eleicao, data_eleicao, id_municipio, id_municipio_tse, sequencial, numero,
               nome_urna, numero_partido, sigla_partido, cargo, situacao, data_nascimento, idade, genero,
               instrucao, ocupacao, raca
        FROM `{BD}.candidatos`
        WHERE sigla_uf = 'RJ' AND ano = @ano""",
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
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--run", action="store_true")
    ap.add_argument("--tables", nargs="*", default=list(QUERIES))
    args = ap.parse_args()

    manifest, total = [], 0
    if args.run:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
    for t in args.tables:
        for ano in ANOS:
            out = OUT_DIR / t / f"{t}_{ano}.parquet"
            if args.run and out.exists():          # retomada: não refaz o que já foi baixado
                print(f"{t:35s} {ano}  já existe, pulando")
                manifest.append(dict(tabela=t, ano=ano, arquivo=str(out), sha256=sha256(out), retomado=True))
                continue
            client = bigquery.Client(project=args.project, credentials=credentials())
            cfg = bigquery.QueryJobConfig(
                dry_run=args.dry_run, use_query_cache=False,
                query_parameters=[bigquery.ScalarQueryParameter("ano", "INT64", ano)])
            job = client.query(QUERIES[t], job_config=cfg)
            if args.dry_run:
                b = job.total_bytes_processed or 0
                total += b
                print(f"{t:35s} {ano}  {b/1e9:8.2f} GB (estimativa)")
                continue
            df = job.result().to_dataframe(create_bqstorage_client=True)
            if df.empty:
                print(f"{t:35s} {ano}  0 linhas")
                manifest.append(dict(tabela=t, ano=ano, linhas=0, arquivo=None, sha256=None,
                                     bytes_processados=job.total_bytes_processed, bytes_cobrados=job.total_bytes_billed))
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            df.to_parquet(out, index=False)
            manifest.append(dict(tabela=t, ano=ano, linhas=len(df), arquivo=str(out), sha256=sha256(out),
                                 bytes_processados=job.total_bytes_processed, bytes_cobrados=job.total_bytes_billed,
                                 job_id=job.job_id, extraido_em=time.strftime("%Y-%m-%d %H:%M:%S")))
            total += job.total_bytes_billed or 0
            print(f"{t:35s} {ano}  {len(df):>10,d} linhas  cobrado {(job.total_bytes_billed or 0)/1e9:.2f} GB")
    print(f"\nTOTAL {'estimado' if args.dry_run else 'cobrado'}: {total/1e9:.1f} GB")
    if args.run:
        mf = OUT_DIR / f"manifesto_{time.strftime('%Y%m%d_%H%M%S')}.json"
        mf.write_text(json.dumps(manifest, indent=1, default=str), encoding="utf-8")
        print("manifesto:", mf)

if __name__ == "__main__":
    sys.exit(main())
