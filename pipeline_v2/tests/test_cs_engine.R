# test_cs_engine.R — testes do motor CS-DID com dados SIMULADOS (efeito verdadeiro conhecido).
# Nenhum dado real é usado aqui.
suppressPackageStartupMessages(library(data.table))
.dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(.dir, "..", "R", "cs_engine.R"))
CS_XFORMLA_PADRAO <- ~ mun   # dados simulados não têm a renda do Censo; os testes usam a especificação só com município

TAU <- 0.05
simula <- function(seed = 1, n = 900, choque_mun = 0.10) {
  set.seed(seed)
  anos <- c(2008, 2012, 2016, 2020, 2024)
  u <- data.table(place_id = sprintf("p%04d", 1:n), mun = sample(sprintf("m%d", 1:6), n, TRUE))
  # timing correlacionado com município: m1 concentra a coorte 2012 (como o Rio)
  u[, g := fifelse(mun == "m1", sample(c(0, 2012, 2016), .N, TRUE, prob = c(.4, .45, .15)),
                   sample(c(0, 2012, 2016, 2020, 2024), .N, TRUE, prob = c(.6, .05, .1, .15, .1)))]
  u[, `:=`(alfa = rnorm(.N, 0.3, 0.05), peso = round(runif(.N, 2000, 8000)), grade_2km = sprintf("c%03d", (seq_len(.N) - 1) %/% 3))]
  d <- u[, .(ano = anos), by = names(u)]
  # choque município × ano: m1 muda de patamar a partir de 2012 (quebra de tendência própria do município)
  d[, lambda := 0.01 * (ano - 2008) / 4 + fifelse(mun == "m1" & ano >= 2012, choque_mun, 0)]
  d[, y := alfa + lambda + TAU * (g > 0 & ano >= g) + rnorm(.N, 0, 0.02)]
  d[]
}

ok <- function(cond, msg) { cat(sprintf("[%s] %s\n", if (isTRUE(cond)) "PASSA" else "FALHA", msg)); if (!isTRUE(cond)) quit(status = 1) }

d <- simula()

# T1: com tendências por município, recupera tau e não acusa pré-tendência
r1 <- cs_estimar(d, "y", xformla = ~ mun, biters = 499, rotulo = "T1")
a1 <- r1$overall[tipo == "group"]
ok(abs(a1$att - TAU) < 3 * a1$se, sprintf("T1 recupera tau com tendências por município: %.4f (se %.4f)", a1$att, a1$se))
ok(r1$wald_pre$p > 0.01, sprintf("T1 sem pré-tendência: Wald p = %.3f (df = %d)", r1$wald_pre$p, r1$wald_pre$df))

# T2: sem tendências por município, o choque do município 1 contamina o ATT (mostra por que o controle é necessário)
r2 <- cs_estimar(d, "y", xformla = ~ 1, biters = 499, rotulo = "T2")
a2 <- r2$overall[tipo == "group"]
ok(abs(a2$att - TAU) > 3 * a2$se, sprintf("T2 sem tendências por município fica viesado: %.4f (se %.4f)", a2$att, a2$se))

# T3: G1 dispara se houver unidades tratadas no 1º período
d3 <- copy(d); d3[place_id %in% sample(unique(place_id), 30), g := 2008]
e3 <- tryCatch({ cs_estimar(d3, "y", biters = 99, rotulo = "T3"); "sem erro" }, error = function(e) conditionMessage(e))
ok(grepl("G1", e3), "T3 G1 bloqueia unidades tratadas no 1º período")

# T4: reprodução do bug do did na configuração do paper (só eventualmente tratados + coorte 2008):
#     did puro gera células com ATT = 0 e SE ausente; o motor (sem a coorte 2008) não gera nenhuma
d4 <- copy(d3)[g > 0]                                   # NYT puro, sem nunca tratados
d4[, id := .id_num(place_id)]
a4 <- suppressWarnings(did::att_gt("y", "ano", "id", "g", data = as.data.frame(d4), control_group = "notyettreated",
                                   base_period = "universal", allow_unbalanced_panel = TRUE, weightsname = "peso", faster_mode = TRUE))
cel4 <- data.table(g = a4$group, t = a4$t, att = a4$att, se = a4$se)
cel4[, ref := vapply(g, function(gg) max(c(2008, 2012, 2016, 2020)[c(2008, 2012, 2016, 2020) < gg]), numeric(1)) == t]
ok(nrow(cel4[!ref & att == 0 & is.na(se)]) > 0, sprintf("T4 did puro reproduz o bug: %d células zeradas", nrow(cel4[!ref & att == 0 & is.na(se)])))
r4 <- cs_estimar(d4[g != 2008], "y", xformla = ~ 1, biters = 199, rotulo = "T4")   # G3 não pode disparar
ok(all(is.finite(r4$overall$att)), "T4 motor sem a coorte 2008: todas as células identificadas")

# T5: determinismo
r5a <- cs_estimar(d, "y", biters = 199, rotulo = "T5a"); r5b <- cs_estimar(d, "y", biters = 199, rotulo = "T5b")
ok(identical(r5a$overall, r5b$overall) && identical(r5a$event, r5b$event), "T5 duas execuções idênticas (ATT e SE)")

# T6: G4 remove município só com tratados
d6 <- copy(d); d6[mun == "m6", g := 2016]
r6 <- cs_estimar(d6, "y", biters = 99, rotulo = "T6")
ok(!is.null(r6$log) && grepl("m6", r6$log), "T6 G4 remove município sem controles")

# T7: contraste padronizado
dc <- copy(d)[, `:=`(m_pref = y, m_ver = y / 10)]
dc <- cria_contraste(dc, "m", padronizar = TRUE)
ok(abs(mean(dc[ano == 2008 & g == 0, m_contraste])) < 1e-8 + abs(mean(dc[ano == 2008 & g == 0, m_pref]) / sd(dc[ano == 2008 & g == 0, m_pref]) - mean(dc[ano == 2008 & g == 0, m_ver]) / sd(dc[ano == 2008 & g == 0, m_ver])),
   "T7 contraste padronizado calculado com a escala do 1º período dos controles")
# T8: com clusters de tamanhos desiguais, a versão analítica da regra do did (média no cluster) reproduz o SE do
#     bootstrap do did (até ruído de simulação), e difere do CRVE padrão (soma no cluster)
d8 <- simula(seed = 5)
tam <- c(rep(1, 150), rep(5, 60), rep(30, 15))                         # 225 clusters (1, 5 e 30 locais) = 900 locais
cl_lab <- rep(sprintf("k%03d", seq_along(tam)), tam); stopifnot(length(cl_lab) == uniqueN(d8$place_id))
d8[, grade_2km := cl_lab[match(place_id, sort(unique(place_id)))]]
d8[, y := y + rnorm(1, 0, 0.05), by = .(grade_2km, ano)]              # choque comum no cluster
r8 <- cs_estimar(d8, "y", biters = 4999, rotulo = "T8")
se_boot <- r8$overall[tipo == "group", se]
ok(abs(r8$se_group_did_analitico / se_boot - 1) < 0.10,
   sprintf("T8 SE analítico (regra do did) = %.4f ~ bootstrap %.4f; CRVE = %.4f", r8$se_group_did_analitico, se_boot, r8$se_group_crve))
cat("TODOS OS TESTES PASSARAM\n")
