# W05_composicao.R — composição do eleitorado (ordenação geográfica dos eleitores). Testa se a entrada muda a
# composição do eleitorado do local, o que poderia gerar voto em bloco sem mudança de comportamento.
# Desfechos por local × ano municipal (eleitorado registrado na data da eleição):
#   log_aptos  : log do número de eleitores aptos do local
#   fem        : share de mulheres;  ate24 : share com até 24 anos;  mais60 : share com 60 anos ou mais
#   ate_fund   : share com no máximo fundamental completo;  superior : share com superior completo ou incompleto
# Perfil: basedosdados_v3/perfil_eleitorado_secao_agregado (extrair_bd_v3.py), seção → local físico pelo pipeline v2
# (secao_place; em 2008, sem as seções não validadas, como na versão principal).
# Especificação principal (motor CS-DID, ~ mun + lrenda, reg, NYT + NT, fronteira 1 km, balanceado, group, CRVE 2 km).
# Saída: resultados/W05_composicao.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

SP <- as.data.table(read_parquet(file.path(SNAP, "secao_place.parquet")))[ano %in% ANOS]
cat("métodos de ligação seção → local:\n"); print(SP[, .N, by = .(ano, metodo)][order(ano, metodo)])
SP <- SP[!metodo %in% "secao_2010_nao_validada"]
PF <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/perfil_eleitorado_secao_agregado.parquet")))[ano %in% ANOS]
PF[, `:=`(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao))]
X <- merge(PF, SP[, .(ano, mun, zona, secao, place_id)], by = c("ano", "mun", "zona", "secao"))
cat(sprintf("eleitores do perfil ligados a locais: %.1f%%\n", 100 * X[, sum(eleitores)] / PF[, sum(eleitores)]))
C <- X[, .(el_perfil = sum(eleitores), fem = sum(n_fem) / sum(n_genero), ate24 = sum(n_ate24) / sum(n_idade),
           mais60 = sum(n_60mais) / sum(n_idade), ate_fund = sum(n_ate_fund) / sum(n_instrucao), superior = sum(n_superior) / sum(n_instrucao)),
       by = .(ano, place_id)]
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, C, by = c("place_id", "ano"), all.x = TRUE)
PM[, log_aptos := log(aptos)]
cat(sprintf("correlação aptos x eleitores do perfil: %.4f\n", PM[!is.na(el_perfil), cor(aptos, el_perfil)]))

YS <- c("log_aptos", "fem", "ate24", "mais60", "ate_fund", "superior")
res <- list()
for (f in c("trafico", "milicia")) {
  d0 <- PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
  for (yv in YS) {
    fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(f, yv)), error = function(e) { cat("ERRO", f, yv, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    base <- d[ano == min(ano) & g > 0, mean(get(yv))]
    res[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                                      pre_p = r$wald_pre_crve$p, media_pre_tratados = base, tratados = sum(r$n$por_coorte[u_g > 0]$N),
                                      unidades = r$n$unidades, excluidos_na = length(fora))
    cat(sprintf("%-8s %-10s ATT %+.4f (%.4f) p %.3f pré %.3f | média 2008 tratados %.3f\n", f, yv, g$att, r$se_group_crve,
                res[[paste(f, yv)]]$p, r$wald_pre_crve$p, base))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W05_composicao.csv")); cat("OK W05\n")
