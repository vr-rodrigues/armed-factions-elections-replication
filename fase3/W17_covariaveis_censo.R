# W17_covariaveis_censo.R — tendências paralelas condicionais ao perfil socioeconômico do entorno
# Preocupação: grupos armados entram em bairros mais pobres do que os vizinhos a 1 km, e o voto de bairros pobres pode
# seguir trajetória própria (por exemplo, ganho de quem está no governo ou onda partidária). Com ~ mun, a regressão
# de resultado do CS-DID condiciona só no município; aqui condiciona também na renda e na densidade do entorno
# do local, medidas no Censo de 2010 (antes de quase todas as entradas), o que permite tendências diferentes por renda.
# 1. Covariáveis por local físico: setores censitários de 2010 a até 500 m do local; cada setor entra com peso igual à sua
#    população vezes a fração da sua área dentro do raio. renda = média ponderada do rendimento nominal médio mensal dos
#    responsáveis por domicílio (V005 do arquivo Básico); pop500 = população estimada dentro do raio.
# 2. Balanço: diferença de log(renda) entre tratados e controles da amostra principal, dentro do município.
# 3. Estimativas: as 12 células da matriz e o comparecimento, na mesma amostra, com ~ mun, ~ mun + log(renda)
#    (especificação principal) e ~ mun + log(renda) + log(pop500). Mesma especificação do motor no restante.
# Saídas: EXT/censo2010_local.parquet; resultados/W17_covariaveis_censo.csv, W17_balanco_renda.csv, W17_checagem.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(sf); library(fixest) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
BD2 <- file.path(AFE_DADOS, "basedosdados_v2"); BD4 <- file.path(AFE_DADOS, "basedosdados_v4")
OUT <- file.path(F3DIR, "resultados"); CRS_M <- 31983; RAIO <- 500
sf_use_s2(FALSE)

# ---------------- 1. covariáveis por local ----------------
arq_cov <- file.path(EXT, "censo2010_local.parquet")
fontes_cov <- c(file.path(BD2, "setores_2010.parquet"), file.path(BD4, "setores_2010_perfil.parquet"), file.path(SNAP, "places.parquet"))
if (!file.exists(arq_cov) || file.mtime(arq_cov) < max(file.mtime(fontes_cov))) {   # refaz se alguma fonte for mais nova
  S <- as.data.table(read_parquet(file.path(BD2, "setores_2010.parquet")))[!is.na(wkt)]
  P <- as.data.table(read_parquet(file.path(BD4, "setores_2010_perfil.parquet")))
  S <- merge(S[, .(id_setor_censitario, populacao, wkt)], P[, .(id_setor_censitario, renda = renda_resp_media)], by = "id_setor_censitario", all.x = TRUE)
  S[is.na(populacao), populacao := 0]
  sfS <- st_make_valid(st_transform(st_make_valid(st_as_sf(S, wkt = "wkt", crs = 4326)), CRS_M)); sfS <- sfS[!st_is_empty(sfS), ]
  sfS$area_setor <- as.numeric(st_area(sfS))
  L <- as.data.table(read_parquet(file.path(SNAP, "places.parquet")))[!is.na(lat), .(place_id, lon, lat)]
  buf <- st_buffer(st_transform(st_as_sf(L, coords = c("lon", "lat"), crs = 4326), CRS_M), RAIO)
  it <- suppressWarnings(st_intersection(buf[, "place_id"], sfS[, c("id_setor_censitario", "populacao", "renda", "area_setor")]))
  it$w <- it$populacao * as.numeric(st_area(it)) / it$area_setor
  I <- as.data.table(st_drop_geometry(it))
  COV <- I[, .(pop500 = sum(w), renda = if (sum(w[!is.na(renda)]) > 0) sum(w[!is.na(renda)] * renda[!is.na(renda)]) / sum(w[!is.na(renda)]) else NA_real_,
               setores = .N, cobertura_renda = if (sum(w) > 0) sum(w[!is.na(renda)]) / sum(w) else NA_real_), by = place_id]
  COV <- merge(L[, .(place_id)], COV, by = "place_id", all.x = TRUE)
  write_parquet(COV, arq_cov)
}
COV <- as.data.table(read_parquet(arq_cov))
COV[, `:=`(lrenda = ifelse(!is.na(renda) & renda > 0, log(renda), NA_real_), ldens = ifelse(!is.na(pop500) & pop500 > 0, log(pop500), NA_real_))]
cat(sprintf("locais: %d | com renda: %d | com densidade: %d | renda mediana: %.0f | pop500 mediana: %.0f\n",
            nrow(COV), sum(!is.na(COV$lrenda)), sum(!is.na(COV$ldens)), median(COV$renda, na.rm = TRUE), median(COV$pop500, na.rm = TRUE)))

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, X[, .(place_id, ano, saldo_pref, saldo_ver)], by = c("place_id", "ano"), all.x = TRUE)
PM <- merge(PM, COV[, .(place_id, lrenda, ldens, renda, pop500)], by = "place_id", all.x = TRUE)
YS <- c("hhi_pref", "margin_pref", "saldo_pref", "hhi_ver", "margin_ver", "saldo_ver", "comparecimento_taxa")
sem_na <- function(d, y) { fora <- unique(d$place_id[is.na(d[[y]])]); d[!place_id %in% fora] }
amostra <- function(f) PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]

# ---------------- 2. balanço de renda dentro do município ----------------
bal <- rbindlist(lapply(c("trafico", "milicia"), function(f) {
  d <- amostra(f)[ano == min(ano) & !is.na(lrenda) & !is.na(ldens)]; d[, trat := as.integer(g > 0)]
  m1 <- feols(lrenda ~ trat | mun, d, weights = ~ peso, cluster = ~ grade_2km)
  m2 <- feols(ldens ~ trat | mun, d, weights = ~ peso, cluster = ~ grade_2km)
  data.table(faccao = f, variavel = c("lrenda", "ldens"), dif = c(coef(m1)[["trat"]], coef(m2)[["trat"]]), se = c(se(m1)[["trat"]], se(m2)[["trat"]]),
             p = c(pvalue(m1)[["trat"]], pvalue(m2)[["trat"]]), tratados = sum(d$trat), controles = sum(1 - d$trat),
             media_tratados = c(d[trat == 1, weighted.mean(renda, peso)], d[trat == 1, weighted.mean(pop500, peso)]),
             media_controles = c(d[trat == 0, weighted.mean(renda, peso)], d[trat == 0, weighted.mean(pop500, peso)]))
}))
fwrite(bal, file.path(OUT, "W17_balanco_renda.csv")); print(bal)

# ---------------- 3. estimativas com covariáveis ----------------
ESP <- list(mun = ~ mun, renda = ~ mun + lrenda, renda_dens = ~ mun + lrenda + ldens)
res <- list()
for (f in c("trafico", "milicia")) {
  d0 <- amostra(f); n0 <- uniqueN(d0$place_id); t0 <- uniqueN(d0[g > 0]$place_id)
  d0 <- d0[!is.na(lrenda) & !is.na(ldens)]
  cat(sprintf("%s: %d locais (%d tratados) na amostra principal; %d (%d tratados) com covariáveis\n", f, n0, t0, uniqueN(d0$place_id), uniqueN(d0[g > 0]$place_id)))
  for (y in YS) for (e in names(ESP)) {
    rot <- paste(f, y, e)
    r <- tryCatch(cs_estimar(sem_na(d0, y), y, xformla = ESP[[e]], biters = 99, rotulo = rot), error = function(err) { cat("ERRO", rot, conditionMessage(err), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[rot]] <- data.table(faccao = f, outcome = y, espec = e, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                             pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades, clusters = r$n$clusters)
    cat(sprintf("%-40s %+.4f (%.4f) p %.3f  pré %.3f\n", rot, g$att, r$se_group_crve, res[[rot]]$p, r$wald_pre_crve$p))
  }
}
R <- rbindlist(res); fwrite(R, file.path(OUT, "W17_covariaveis_censo.csv"))

# conferência: com ~ mun + log(renda), a estimativa é a da especificação principal (W15)
if (file.exists(file.path(OUT, "W15_matriz_conjunta.csv"))) {   # numa execução do zero, o W17 roda antes do W15 (refaz a renda) e de novo no fim
  W15 <- fread(file.path(OUT, "W15_matriz_conjunta.csv"))[, .(faccao, outcome, att_w15 = att, unidades_w15 = unidades_E)]
  ch <- merge(R[espec == "renda", .(faccao, outcome, att, unidades)], W15, by = c("faccao", "outcome"))   # o W15 principal é com renda
  ch[, dif := att - att_w15]; fwrite(ch, file.path(OUT, "W17_checagem.csv")); print(ch)
}
cat("OK W17\n")
