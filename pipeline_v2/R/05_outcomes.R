# 05_outcomes.R — outcomes por local físico × ano × cargo (famílias F1–F3)
# Shares s_k sobre votos nominais (vereador/deputados: legenda fora do denominador; share de legenda reportado à parte).
# F1: hhi, enc, top1, margin (s(1) - s(2)), n_cand_votados
# F2: dissim = 1/2 sum_k |s_ik - S_{m,-i,k}| (município sem o próprio local)
#     exc_hhi = hhi_i - hhi_m (município inteiro); exc_hhi_loo = hhi_i - hhi_{m,-i}
#     exc_vencedor = s_i(k*) - S_{m,-i}(k*), k* = mais votado no município (1º turno)
# F3: comparecimento = comparecimento / aptos ; brancos_nulos = (brancos + nulos) / votos totais do cargo
# Referência municipal (S_m, HHI_m, vencedor): TODAS as seções do município (votos_cand_mun), igual para as
# duas versões do mapa; o local i é retirado (leave-one-out) com os seus próprios votos.
# Saída: OUT_DIR/outcomes_place.parquet

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
cat("05_outcomes.R\n")

vc <- as.data.table(read_parquet(file.path(OUT_DIR, "votos_cand_place.parquet")))
dd <- as.data.table(read_parquet(file.path(OUT_DIR, "detalhes_place.parquet")))
# versão robusta só difere da principal em 2008
vc <- vc[versao == "principal" | ano %in% c(2006, 2008)]; dd <- dd[versao == "principal" | ano %in% c(2006, 2008)]
vm <- as.data.table(read_parquet(file.path(OUT_DIR, "votos_cand_mun.parquet")))
vm[, cand := paste(numero_candidato, sequencial_candidato)]

K <- c("versao", "ano", "mun", "cargo")
vc[, cand := paste(numero_candidato, sequencial_candidato)]
vc[, v_i := sum(votos), by = c(K, "place_id")]
vc[, s := votos / v_i]
Km <- c("ano", "mun", "cargo")
ref <- vm[, .(V_mk = sum(votos)), by = c(Km, "cand")][, V_m := sum(V_mk), by = Km]
vc <- merge(vc, ref, by = c(Km, "cand"), all.x = TRUE)
check(!anyNA(vc$V_mk), "candidato do local ausente da referência municipal")
vc[, S_loo := fifelse(V_m - v_i > 0, (V_mk - votos) / (V_m - v_i), NA_real_)]
vc[, S_m := V_mk / V_m]

# HHI municipal (inteiro) e vencedor municipal
mun_ref <- ref[, .(hhi_m = sum((V_mk / V_m)^2), vencedor = cand[order(-V_mk, cand)][1]), by = Km]
vc <- merge(vc, mun_ref, by = Km)

# HHI municipal sem o local i: sum_k ((V_mk - v_ik)/(V_m - v_i))^2 sobre todos os candidatos do município
loo <- vc[, .(sum_S2_presentes = sum(S_loo^2, na.rm = TRUE),
              soma_V2_presentes = sum(V_mk^2), V_m = V_m[1], v_i = v_i[1]), by = c(K, "place_id")]
tot_V2 <- ref[, .(soma_V2_m = sum(V_mk^2)), by = Km]
loo <- merge(loo, tot_V2, by = Km)
# candidatos sem voto no local mantêm V_mk; contribuição = (soma_V2_m - soma_V2_presentes)/(V_m - v_i)^2
loo[, hhi_m_loo := fifelse(V_m - v_i > 0, sum_S2_presentes + (soma_V2_m - soma_V2_presentes) / (V_m - v_i)^2, NA_real_)]

out <- vc[, {
  o <- order(-s)
  list(n_cand_votados = .N, votos_cand = v_i[1],
       hhi = sum(s^2), top1 = s[o[1]], top2 = if (.N > 1) s[o[2]] else 0,
       # dissimilaridade: candidatos presentes + massa dos candidatos ausentes no local
       dissim = 0.5 * (sum(abs(s - S_loo), na.rm = TRUE) + (1 - sum(S_loo, na.rm = TRUE))),
       s_vencedor = sum(s[cand == vencedor[1]]), S_vencedor_loo = {
         x <- S_loo[cand == vencedor[1]]
         if (length(x)) x[1] else NA_real_ },
       hhi_m = hhi_m[1])
}, by = c(K, "place_id")]
# vencedor municipal sem votos no local: S_loo vem do total municipal
venc <- merge(mun_ref, ref, by.x = c(Km, "vencedor"), by.y = c(Km, "cand"))[, c(Km, "V_mk", "V_m"), with = FALSE]
out <- merge(out, venc, by = Km, all.x = TRUE)
out[is.na(S_vencedor_loo), S_vencedor_loo := V_mk / (V_m - votos_cand)]
out[, c("V_mk", "V_m") := NULL]
out <- merge(out, loo[, c(K, "place_id", "hhi_m_loo"), with = FALSE], by = c(K, "place_id"))

out[, `:=`(enc = 1 / hhi, margin = top1 - top2,
           exc_hhi = hhi - hhi_m, exc_hhi_loo = hhi - hhi_m_loo,
           exc_vencedor = s_vencedor - S_vencedor_loo)]

out <- merge(out, dd, by = c("versao", "ano", "mun", "place_id", "cargo"), all = TRUE)
check(out[!is.na(votos_cand), all(votos_cand == votos_nominais)], "votos de candidatos != votos nominais apos merge")
out[, votos_por_eleitor := fifelse(cargo == "senador" & ano %in% c(2010, 2018), 2L, 1L)]
out[, `:=`(comparecimento_taxa = comparecimento / aptos,
           brancos_nulos = (votos_brancos + votos_nulos) / (votos_por_eleitor * comparecimento),
           legenda_share = fifelse(votos_nominais + votos_legenda > 0, votos_legenda / (votos_nominais + votos_legenda), NA_real_))]

# checagens
check(out[!is.na(hhi), all(hhi > 0 & hhi <= 1 + 1e-12)], "HHI fora de (0,1]")
check(out[!is.na(dissim), all(dissim >= -1e-12 & dissim <= 1 + 1e-12)], "dissimilaridade fora de [0,1]")
check(out[!is.na(margin), all(margin >= -1e-12 & margin <= 1)], "margem fora de [0,1]")
check(out[!is.na(comparecimento_taxa), all(comparecimento_taxa > 0 & comparecimento_taxa <= 1)], "comparecimento fora de (0,1]")

setorder(out, versao, ano, mun, place_id, cargo)
write_out(out, "outcomes_place")

res <- out[versao == "principal", .(locais = uniqueN(place_id), hhi = round(weighted.mean(hhi, aptos, na.rm = TRUE), 3),
                                    margin = round(weighted.mean(margin, aptos, na.rm = TRUE), 3),
                                    dissim = round(weighted.mean(dissim, aptos, na.rm = TRUE), 3),
                                    exc_hhi = round(weighted.mean(exc_hhi, aptos, na.rm = TRUE), 3),
                                    comparec = round(weighted.mean(comparecimento_taxa, aptos, na.rm = TRUE), 3)),
           by = .(ano, cargo)][order(cargo, ano)]
fwrite(res, file.path(CHECK_DIR, "05_medias_por_ano_cargo.csv"))
print(res[cargo %in% c("prefeito", "vereador", "governador", "deputado estadual")])
cat("OK 05\n")
