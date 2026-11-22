# cs_engine.R — motor único de estimação Callaway & Sant'Anna (pacote did), com guardas
# Uso: source("R/cs_engine.R"); r <- cs_estimar(dados, y = "dissim_contraste", ...)
# Guardas (falham alto, nunca gravam zero como estimativa):
#   G1 nenhuma unidade com 0 < g <= 1º período (bug do did 2.3.0 que apaga a última coorte)
#   G2 nenhum aviso de "No available control units", matriz singular ou overlap
#   G3 nenhuma célula não-referência com ATT exatamente 0 e SE ausente/zero
#   G4 municípios usados em xformla têm tratados e controles na amostra (os que não têm são removidos e logados)
#   G5 versão do did e do DRDID registradas; faster_mode = FALSE explícito; seed fixa.
#      Nota: no did 2.3.0, o modo rápido (faster_mode = TRUE) acusa "matriz singular" com
#      covariáveis categóricas (~ mun) mesmo com posto completo e transforma a célula em ATT = 0 silenciosamente;
#      o modo clássico não tem esse problema. Com os sempre tratados excluídos (G1), o modo clássico não sofre
#      o bug de truncamento da última coorte.

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(did) })

CS_VERSOES <- list(did = as.character(packageVersion("did")), DRDID = as.character(packageVersion("DRDID")))

# Especificação principal: a regressão de resultado condiciona no município e no log da
# renda do entorno do local no Censo 2010 (renda média dos responsáveis nos setores a até 500 m; fase3/W17). As
# covariáveis do Censo (lrenda, ldens) são juntadas aqui, pelo identificador da unidade, quando a fórmula as pede e o
# painel não as traz. Unidades sem a covariável saem da estimação inteira (registrado em $log). Para condicionar
# só no município, passe xformla = ~ mun.
CS_XFORMLA_PADRAO <- ~ mun + lrenda
CS_COV_ARQ <- file.path(AFE_DADOS, "pipeline_v2_ext/censo2010_local.parquet")
.cs_cov_env <- new.env()
cs_covariaveis <- function() {
  if (is.null(.cs_cov_env$cov)) {
    cv <- as.data.table(arrow::read_parquet(CS_COV_ARQ))
    cv[, `:=`(lrenda = ifelse(!is.na(renda) & renda > 0, log(renda), NA_real_), ldens = ifelse(!is.na(pop500) & pop500 > 0, log(pop500), NA_real_))]
    .cs_cov_env$cov <- cv[, .(place_id, lrenda, ldens)]
  }
  .cs_cov_env$cov
}

# id e cluster numéricos com ordenação independente de locale
.id_num <- function(x) { lv <- sort(unique(as.character(x)), method = "radix"); match(as.character(x), lv) }

cs_estimar <- function(dados, y, gname = "g", tname = "ano", idname = "place_id",
                       peso = "peso", cluster = "grade_2km",
                       xformla = CS_XFORMLA_PADRAO, est_method = "reg",
                       control_group = "notyettreated", base_period = "universal",
                       biters = 999, seed = 20261009, alp = 0.05, rotulo = y, retorna_if = FALSE,
                       anticipation = 0) {
  # anticipation (padrão 0 = sem antecipação): número de ELEIÇÕES antes da
  # entrada tratadas como possivelmente afetadas; com base universal, a referência passa a ser g - (1 + anticipation)
  # eleições. O did mede anticipation nas unidades de tname (usa t + anticipation < g), por isso o valor é convertido
  # em anos (x passo do calendário) antes da chamada. Coortes sem essa base devem ser
  # removidas antes (o G2 acusa).
  # retorna_if = TRUE: devolve também as funções de influência do efeito agregado
  # (group) e do event study, com a tabela de unidades na ordem das linhas, para inferência espacial alternativa.
  # Não altera nenhum cálculo.
  dados <- as.data.table(dados)
  # covariáveis do Censo pedidas pela fórmula: junta se faltarem e remove as unidades sem valor
  log_cov <- NULL
  cv_ped <- intersect(all.vars(xformla), c("lrenda", "ldens"))
  if (length(cv_ped)) {
    falta <- setdiff(cv_ped, names(dados))
    if (length(falta)) { cv <- copy(cs_covariaveis()[, c("place_id", falta), with = FALSE]); setnames(cv, "place_id", idname)
      dados <- merge(dados, cv, by = idname, all.x = TRUE) }
    sem <- unique(dados[[idname]][!stats::complete.cases(dados[, cv_ped, with = FALSE])])
    if (length(sem)) { log_cov <- sprintf("covariáveis do Censo ausentes: %d unidades removidas", length(sem)); dados <- dados[!dados[[idname]] %in% sem] }
  }
  keep <- !is.na(dados[[y]]) & !is.na(dados[[peso]]) & dados[[peso]] > 0
  cols <- unique(c(idname, tname, gname, y, peso, cluster, all.vars(xformla)))
  d <- dados[keep, cols, with = FALSE]
  # covariáveis categóricas como texto (o did não aceita factor() na fórmula; texto vira dummies)
  for (v in intersect(all.vars(xformla), c("mun", "zona", "grade_2km", "grade_5km"))) set(d, j = v, value = as.character(d[[v]]))
  setnames(d, c(idname, tname, gname, y, peso), c("u_id_chr", "u_t", "u_g", "u_y", "u_w"))
  t1 <- min(d$u_t)
  # painel completo: com allow_unbalanced_panel = FALSE o did descartaria a unidade e as funções
  # de influência perderiam o alinhamento com o vetor de clusters; falha alto com mensagem clara
  inc <- d[, .N, by = u_id_chr][N < uniqueN(d$u_t)]
  if (nrow(inc)) stop(sprintf("[%s] painel incompleto: %d unidades sem todos os períodos (remova-as antes, como sem_na() em W01)", rotulo, nrow(inc)))
  # G1
  sempre <- d[u_g > 0 & u_g <= t1, uniqueN(u_id_chr)]
  if (sempre > 0) stop(sprintf("[%s] G1: %d unidades com 0 < g <= 1º período (%d). Remova-as antes (bug do did).", rotulo, sempre, t1))
  # G4: municípios sem controles ou sem tratados
  log_g4 <- NULL
  if ("mun" %in% all.vars(xformla)) {
    # controle potencial no município: nunca tratado (g = 0) ou, com "notyettreated", uma coorte posterior a
    # alguma coorte tratada do mesmo município
    comp <- unique(d[, .(mun, u_id_chr, u_g)])[, .(tem_trat = any(u_g > 0),
              tem_ctrl = any(u_g == 0) | (control_group == "notyettreated" & uniqueN(u_g[u_g > 0]) > 1)), by = mun]
    fora <- comp[!(tem_trat & tem_ctrl), mun]
    if (length(fora)) { log_g4 <- sprintf("G4: removidos %d municípios sem tratados e controles: %s", length(fora), paste(fora, collapse = ",")); d <- d[!mun %in% fora] }
  }
  d[, u_id := .id_num(u_id_chr)]
  d[, u_cl := .id_num(d[[cluster]])]
  setorder(d, u_id, u_t)

  tl <- sort(unique(d$u_t)); passo <- diff(tl)[1]
  if (anticipation > 0 && any(diff(tl) != passo)) stop(sprintf("[%s] anticipation exige calendário regular", rotulo))
  avisos <- character(0)
  set.seed(seed)
  att <- withCallingHandlers(
    att_gt(yname = "u_y", tname = "u_t", idname = "u_id", gname = "u_g", data = as.data.frame(d),
           xformla = xformla, est_method = est_method, control_group = control_group,
           base_period = base_period, weightsname = "u_w", allow_unbalanced_panel = FALSE,
           clustervars = "u_cl", bstrap = TRUE, biters = biters, cband = FALSE,
           alp = alp, faster_mode = FALSE, print_details = FALSE, anticipation = anticipation * passo),   # G5: modo clássico; anticipation em anos
    warning = function(w) { avisos <<- c(avisos, conditionMessage(w)); invokeRestart("muffleWarning") })
  # G2
  ruins <- grep("No avail|singular|overlap|Not enough control|no pre-treatment", avisos, value = TRUE, ignore.case = TRUE)
  if (length(ruins)) stop(sprintf("[%s] G2: avisos de identificação: %s", rotulo, paste(unique(ruins), collapse = " | ")))
  # G3: células não-referência (com base universal, referência = último período antes de g)
  cel <- data.table(g = att$group, t = att$t, att = att$att, se = att$se)
  cel[, ref := vapply(g, function(gg) { v <- sort(tl[tl < gg], decreasing = TRUE); if (length(v) > anticipation) v[1 + anticipation] else NA_real_ },
                      numeric(1)) == t]
  cel[is.na(ref), ref := FALSE]
  zeros <- cel[!ref & att == 0 & (is.na(se) | se == 0)]
  if (nrow(zeros)) stop(sprintf("[%s] G3: %d células não-referência com ATT = 0 e SE ausente", rotulo, nrow(zeros)))

  set.seed(seed); ag_g <- aggte(att, type = "group", na.rm = FALSE)
  set.seed(seed); ag_s <- aggte(att, type = "simple", na.rm = FALSE)
  set.seed(seed); ag_d <- aggte(att, type = "dynamic", na.rm = FALSE)

  # pré-tendência: Wald conjunto dos coeficientes e < 0 não-referência, variância clusterizada
  e_ref <- -(1 + anticipation) * passo
  e <- ag_d$egt; pre <- which(e < e_ref)                                  # com anticipation = 0: e < 0 exceto a referência
  wald <- data.table(stat = NA_real_, df = length(pre), p = NA_real_)
  if (length(pre)) {
    psi <- as.matrix(ag_d$inf.function$dynamic.inf.func.e)[, pre, drop = FALSE]
    n <- nrow(psi)
    cl_unit <- unique(d[, .(u_id, u_cl)])[order(u_id)]$u_cl
    psi_c <- rowsum(psi, cl_unit)
    V <- crossprod(psi_c) / n^2
    b <- ag_d$att.egt[pre]
    st <- tryCatch(as.numeric(t(b) %*% solve(V) %*% b), error = function(e) stop(sprintf("[%s] Wald: matriz singular", rotulo)))
    wald <- data.table(stat = st, df = length(pre), p = 1 - pchisq(st, length(pre)))
  }

  # Covariâncias clusterizadas do event study (todas as e; a referência tem variância 0). Duas versões:
  #   crve: padrão (Liang-Zeger), soma das funções de influência no cluster: sum_c S_c S_c' / n^2
  #   did : a mesma regra do bootstrap multiplicador do did (did::mboot), média no cluster com peso igual por
  #         cluster: sum_c psibar_c psibar_c' / G^2. Coincidem com clusters de tamanho igual.
  psi_all <- as.matrix(ag_d$inf.function$dynamic.inf.func.e)
  cl_u <- unique(d[, .(u_id, u_cl)])[order(u_id)]$u_cl
  stopifnot(length(cl_u) == nrow(psi_all))
  n_c <- as.numeric(table(cl_u)[as.character(sort(unique(cl_u)))]); G <- length(n_c)
  V_crve <- function(psi) crossprod(rowsum(psi, cl_u, reorder = TRUE)) / nrow(psi)^2
  V_did  <- function(psi) crossprod(rowsum(psi, cl_u, reorder = TRUE) / n_c) / G^2
  V_ev <- V_crve(psi_all); V_ev_did <- V_did(psi_all)
  dimnames(V_ev) <- dimnames(V_ev_did) <- list(ag_d$egt, ag_d$egt)
  psi_g <- as.matrix(ag_g$inf.function$selective.inf.func)
  se_g_crve <- sqrt(V_crve(psi_g)[1, 1]); se_g_did <- sqrt(V_did(psi_g)[1, 1])
  # Wald de pré-tendência nas duas versões
  wald_v <- function(V) {
    if (!length(pre)) return(data.table(stat = NA_real_, df = 0L, p = NA_real_))
    b <- ag_d$att.egt[pre]; S <- V[pre, pre, drop = FALSE]
    st <- tryCatch(as.numeric(t(b) %*% solve(S) %*% b), error = function(e) stop(sprintf("[%s] Wald: matriz singular", rotulo)))
    data.table(stat = st, df = length(pre), p = 1 - pchisq(st, length(pre)))
  }
  wald_crve <- wald_v(V_ev); wald_did <- wald_v(V_ev_did)

  ncoh <- unique(d[, .(u_id, u_g)])[, .N, by = u_g][order(u_g)]
  extra <- if (retorna_if) list(psi_group = psi_g, psi_event = psi_all,
                                unidades = unique(d[, .(u_id, u_id_chr, u_cl)])[order(u_id)]) else NULL
  c(extra, list(rotulo = rotulo, y = y,
       overall = data.table(tipo = c("group", "simple", "dynamic"),
                            att = c(ag_g$overall.att, ag_s$overall.att, ag_d$overall.att),
                            se = c(ag_g$overall.se, ag_s$overall.se, ag_d$overall.se)),
       event = data.table(e = ag_d$egt, att = ag_d$att.egt, se = ag_d$se.egt),
       grupos = data.table(g = ag_g$egt, att = ag_g$att.egt, se = ag_g$se.egt),
       celulas = cel, wald_pre = wald, wald_pre_crve = wald_crve, wald_pre_did = wald_did,
       V_event = V_ev, V_event_did = V_ev_did,
       se_group_crve = se_g_crve, se_group_did_analitico = se_g_did,
       n = list(unidades = uniqueN(d$u_id), clusters = uniqueN(d$u_cl), por_coorte = ncoh, municipios = uniqueN(d$mun)),
       avisos = unique(avisos), log = if (is.null(log_g4) && is.null(log_cov)) NULL else paste(c(log_g4, log_cov), collapse = "; "),
       versoes = CS_VERSOES, seed = seed, xformla = paste(deparse(xformla), collapse = "")))
}

# Contraste prefeito - vereador. Para F1, cada cargo é padronizado pelo DP do outcome
# no 1º período entre os controles da amostra (escala fixa, pré-determinada).
# `escala` (opcional): c(sd_pref, sd_ver) fixada de fora (ex.: da amostra principal), para que amostras de
# robustez usem a mesma escala.
cria_contraste <- function(dados, var, padronizar, g = "g", tname = "ano", escala = NULL) {
  d <- copy(as.data.table(dados))
  a <- d[[paste0(var, "_pref")]]; b <- d[[paste0(var, "_ver")]]
  nova <- paste0(var, "_contraste")
  if (padronizar) {
    if (!is.null(escala)) { sd_a <- escala[["sd_pref"]]; sd_b <- escala[["sd_ver"]] } else {
      base <- d[[tname]] == min(d[[tname]]) & d[[g]] == 0
      sd_a <- sd(a[base], na.rm = TRUE); sd_b <- sd(b[base], na.rm = TRUE) }
    stopifnot(is.finite(sd_a), is.finite(sd_b), sd_a > 0, sd_b > 0)
    set(d, j = nova, value = a / sd_a - b / sd_b)
    attr(d, "escala") <- c(sd_pref = sd_a, sd_ver = sd_b)
  } else {
    set(d, j = nova, value = a - b)
  }
  d
}
