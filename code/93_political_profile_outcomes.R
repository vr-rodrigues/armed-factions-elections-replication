# ============================================================================
# 93_political_profile_outcomes.R
# ============================================================================
#
# Candidate-profile and party-bloc mechanism outcomes.
#
# Inputs:
#   data/electoral_competition_measures.csv
#   data/qt_aptos_by_location.csv
#   data/locais_votacao_treatment_annual.csv
#   data/loc_faction_changes.csv
#   data/loc_to_territory.csv
#   TSE raw municipal files:
#     votacao_secao_RJ_{2008,2012,2016,2020,2024}.csv
#     candidatos/consulta_cand_{2008,2012,2016,2020,2024}_RJ.csv
#
# Outputs:
#   data/candidate_profile_by_location.csv
#   data/party_bloc_by_location.csv
#   data/party_specific_by_location.csv
#   results/tab93_party_classification_coverage.csv
#   results/tab93_political_profile_overall.csv
#   results/tab93_political_profile_es.csv
# ============================================================================ 

library(data.table)
library(did)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                         value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
DATA_DIR <- file.path(BASE_DIR, "data")
OUT_DIR <- file.path(BASE_DIR, "results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("93_political_profile_outcomes.R\n")
cat("Candidate profile and party-bloc outcomes\n")
cat("============================================================\n\n")

find_tse_dir <- function() {
  env <- Sys.getenv("TSE_RAW_DIR", "")
  candidates <- c(
    env,
    file.path(DATA_DIR, "raw", "tse"),
    file.path(DATA_DIR, "tse"),
    file.path(dirname(BASE_DIR), "legado", "01_workspace_pre_replication",
              "dados", "tse")
  )
  candidates <- candidates[nzchar(candidates)]
  for (p in candidates) {
    if (dir.exists(p) &&
        file.exists(file.path(p, "votacao_secao_RJ_2024.csv"))) {
      return(normalizePath(p, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Could not find TSE raw directory. Set TSE_RAW_DIR or place files under data/raw/tse.")
}

TSE_DIR <- find_tse_dir()
CAND_DIR <- file.path(TSE_DIR, "candidatos")
cat(sprintf("Using TSE raw dir: %s\n\n", TSE_DIR))

elec_years <- c(2008, 2012, 2016, 2020, 2024)
cargos <- c("Prefeito", "Vereador")

clean_text <- function(x) {
  x <- trimws(as.character(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  toupper(x)
}

title_cargo <- function(x) {
  x2 <- clean_text(x)
  fifelse(x2 == "PREFEITO", "Prefeito",
          fifelse(x2 == "VEREADOR", "Vereador", NA_character_))
}

parse_br_date <- function(x) {
  x <- trimws(as.character(x))
  out <- as.IDate(rep(NA_character_, length(x)))
  ok <- grepl("^\\d{2}/\\d{2}/\\d{4}$", x)
  out[ok] <- as.IDate(x[ok], format = "%d/%m/%Y")
  ok2 <- grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  out[ok2] <- as.IDate(x[ok2])
  out
}

education_score <- function(x) {
  z <- clean_text(x)
  fcase(
    grepl("ANALFABETO", z), 0,
    grepl("LE E ESCREVE", z), 1,
    grepl("FUNDAMENTAL INCOMPLETO", z), 2,
    grepl("FUNDAMENTAL COMPLETO", z), 3,
    grepl("MEDIO INCOMPLETO", z), 4,
    grepl("MEDIO COMPLETO", z), 5,
    grepl("SUPERIOR INCOMPLETO", z), 6,
    grepl("SUPERIOR COMPLETO", z), 7,
    default = NA_real_
  )
}

is_security_occupation <- function(x) {
  z <- clean_text(x)
  grepl(paste(c("POLICIAL", "MILITAR", "BOMBEIRO", "GUARDA",
                "DELEGADO", "SARGENTO", "CABO ", " TENENTE",
                "CAPITAO", "CORONEL", "SEGURANCA", "VIGILANTE",
                "AGENTE DE POLICIA", "INVESTIGADOR DE POLICIA"),
              collapse = "|"), z)
}

is_public_admin_occupation <- function(x) {
  z <- clean_text(x)
  grepl(paste(c("VEREADOR", "PREFEITO", "DEPUTADO", "SENADOR",
                "GOVERNADOR", "SERVIDOR PUBLICO", "FUNCIONARIO PUBLICO",
                "MEMBRO DO PODER", "ADMINISTRADOR PUBLICO"),
              collapse = "|"), z)
}

is_elected_status <- function(x) {
  z <- clean_text(x)
  grepl("ELEITO", z) & !grepl("NAO ELEITO", z)
}

make_party_bloc <- function(parties, bloc) {
  data.table(SG_PARTIDO = parties, bloc = bloc)
}

# Left/center/right coding follows Colonnelli, Pinho Neto, and Teso (2025),
# Table A1. Post-2019 successor labels are mapped to the same bloc where the
# old party name in Table A1 was renamed or merged.
party_bloc_table <- rbindlist(list(
  make_party_bloc(c(
    "PT", "PDT", "PSB", "PC DO B", "PCDOB", "PV", "PMN", "PSOL",
    "SD", "SOLIDARIEDADE", "PROS", "PSTU", "PCB", "REDE", "PCO",
    "UP", "PPL", "MOBILIZA"
  ), "Left"),
  make_party_bloc(c(
    "PMDB", "MDB", "PSDB", "PTB", "AVANTE", "PT DO B", "PTDOB", "PSD"
  ), "Center"),
  make_party_bloc(c(
    "PP", "DEM", "PL", "PR", "PPS", "CIDADANIA", "PSC", "PODE", "PODEMOS",
    "PRB", "REPUBLICANOS", "PATRI", "PATRIOTA", "PSL", "DC", "PTC",
    "AGIR", "PRTB", "NOVO", "PMB", "PRP", "PHS", "PSDC", "PTN", "PEN", "UNIAO",
    "UNIAO BRASIL"
  ), "Right")
))
party_bloc_table[, SG_PARTIDO_STD := clean_text(SG_PARTIDO)]
party_bloc_table <- unique(party_bloc_table[, .(SG_PARTIDO_STD, bloc)],
                           by = "SG_PARTIDO_STD")
party_bloc_table[, ideology_score := fcase(
  bloc == "Left", -1,
  bloc == "Center", 0,
  bloc == "Right", 1
)]

read_candidates_year <- function(yr) {
  f <- file.path(CAND_DIR, sprintf("consulta_cand_%d_RJ.csv", yr))
  if (!file.exists(f)) {
    stop(sprintf("Missing candidate file: %s", f))
  }

  cand <- fread(f, encoding = "Latin-1", showProgress = FALSE)
  cand[, election_year := yr]
  cand[, DS_CARGO_STD := title_cargo(DS_CARGO)]
  cand <- cand[DS_CARGO_STD %in% cargos]

  if (!"CD_MUNICIPIO" %in% names(cand)) {
    cand[, CD_MUNICIPIO := as.integer(SG_UE)]
  }
  cand[, CD_MUNICIPIO := as.integer(CD_MUNICIPIO)]
  cand[, NR_CANDIDATO := as.integer(NR_CANDIDATO)]
  cand[, NR_PARTIDO := as.integer(NR_PARTIDO)]

  if (!"NR_IDADE_DATA_POSSE" %in% names(cand)) {
    cand[, NR_IDADE_DATA_POSSE := NA_real_]
  }
  cand[, birth_date := parse_br_date(DT_NASCIMENTO)]
  cand[, election_date := parse_br_date(DT_ELEICAO)]
  cand[, age_calc := as.numeric(floor((election_date - birth_date) / 365.25))]
  cand[, age := fifelse(!is.na(as.numeric(NR_IDADE_DATA_POSSE)) &
                          as.numeric(NR_IDADE_DATA_POSSE) > 0,
                        as.numeric(NR_IDADE_DATA_POSSE), age_calc)]

  cand[, education_score := education_score(DS_GRAU_INSTRUCAO)]
  cand[, college_complete := education_score >= 7]
  cand[, low_education := !is.na(education_score) & education_score <= 3]
  cand[, security_occupation := is_security_occupation(DS_OCUPACAO)]
  cand[, public_admin_occupation := is_public_admin_occupation(DS_OCUPACAO)]
  cand[, elected := is_elected_status(DS_SIT_TOT_TURNO)]
  cand[, female := clean_text(DS_GENERO) == "FEMININO"]
  cand[, black_pardo := clean_text(DS_COR_RACA) %in% c("PRETA", "PARDA")]

  keep <- c("election_year", "CD_MUNICIPIO", "DS_CARGO_STD", "NR_CANDIDATO",
            "SQ_CANDIDATO", "NR_PARTIDO", "SG_PARTIDO", "NM_CANDIDATO",
            "NM_URNA_CANDIDATO", "age", "education_score",
            "college_complete", "low_education", "security_occupation",
            "public_admin_occupation", "elected", "female", "black_pardo")
  keep <- intersect(keep, names(cand))
  cand <- cand[, ..keep]

  # Collapse rows across turns/status updates. Candidate traits are stable; elected
  # uses any elected status observed for that candidate-election.
  cand <- cand[, .(
    SQ_CANDIDATO = suppressWarnings(as.numeric(SQ_CANDIDATO[!is.na(SQ_CANDIDATO)][1])),
    NR_PARTIDO = NR_PARTIDO[!is.na(NR_PARTIDO)][1],
    SG_PARTIDO = SG_PARTIDO[!is.na(SG_PARTIDO)][1],
    NM_CANDIDATO = NM_CANDIDATO[!is.na(NM_CANDIDATO)][1],
    NM_URNA_CANDIDATO = NM_URNA_CANDIDATO[!is.na(NM_URNA_CANDIDATO)][1],
    age = age[!is.na(age)][1],
    education_score = education_score[!is.na(education_score)][1],
    college_complete = any(college_complete, na.rm = TRUE),
    low_education = any(low_education, na.rm = TRUE),
    security_occupation = any(security_occupation, na.rm = TRUE),
    public_admin_occupation = any(public_admin_occupation, na.rm = TRUE),
    elected = any(elected, na.rm = TRUE),
    female = any(female, na.rm = TRUE),
    black_pardo = any(black_pardo, na.rm = TRUE)
  ), by = .(election_year, CD_MUNICIPIO, DS_CARGO_STD, NR_CANDIDATO)]

  cand
}

read_votes_year <- function(yr, cand) {
  f <- file.path(TSE_DIR, sprintf("votacao_secao_RJ_%d.csv", yr))
  if (!file.exists(f)) {
    stop(sprintf("Missing vote file: %s", f))
  }

  header <- names(fread(f, nrows = 0, showProgress = FALSE))
  select_cols <- intersect(header, c("CD_MUNICIPIO", "NR_ZONA",
                                     "NR_LOCAL_VOTACAO", "NR_TURNO",
                                     "DS_CARGO", "NR_VOTAVEL", "QT_VOTOS",
                                     "SQ_CANDIDATO"))
  dt <- fread(f, select = select_cols, encoding = "Latin-1",
              showProgress = TRUE)
  dt[, election_year := yr]
  dt[, DS_CARGO_STD := title_cargo(DS_CARGO)]
  dt <- dt[NR_TURNO == 1 & DS_CARGO_STD %in% cargos]
  dt[, CD_MUNICIPIO := as.integer(CD_MUNICIPIO)]
  dt[, NR_VOTAVEL := as.integer(NR_VOTAVEL)]
  dt[, QT_VOTOS := as.numeric(QT_VOTOS)]
  dt[, loc_id := paste(CD_MUNICIPIO, NR_ZONA, NR_LOCAL_VOTACAO, sep = "_")]

  # Merge by candidate number, municipality, and office. This also handles 2012,
  # where the voting file has no SQ_CANDIDATO column.
  cand_key <- cand[, .(election_year, CD_MUNICIPIO, DS_CARGO_STD,
                       NR_CANDIDATO, NR_PARTIDO, SG_PARTIDO,
                       age, education_score, college_complete,
                       low_education, security_occupation,
                       public_admin_occupation, elected, female, black_pardo)]
  dt <- merge(
    dt,
    cand_key,
    by.x = c("election_year", "CD_MUNICIPIO", "DS_CARGO_STD", "NR_VOTAVEL"),
    by.y = c("election_year", "CD_MUNICIPIO", "DS_CARGO_STD", "NR_CANDIDATO"),
    all.x = FALSE,
    allow.cartesian = TRUE
  )

  dt[, .(votes = sum(QT_VOTOS, na.rm = TRUE),
         NR_PARTIDO = NR_PARTIDO[1],
         SG_PARTIDO = SG_PARTIDO[1],
         age = age[1],
         education_score = education_score[1],
         college_complete = college_complete[1],
         low_education = low_education[1],
         security_occupation = security_occupation[1],
         public_admin_occupation = public_admin_occupation[1],
         elected = elected[1],
         female = female[1],
         black_pardo = black_pardo[1]),
     by = .(loc_id, election_year, DS_CARGO = DS_CARGO_STD,
            CD_MUNICIPIO, NR_CANDIDATO = NR_VOTAVEL)]
}

cat("--- Loading candidate files ---\n")
candidates <- rbindlist(lapply(elec_years, read_candidates_year), fill = TRUE)
cat(sprintf("Candidates loaded: %d rows\n\n", nrow(candidates)))

cat("--- Loading and aggregating vote files ---\n")
votes_by_candidate <- list()
for (yr in elec_years) {
  cat(sprintf("  Year %d\n", yr))
  cand_yr <- candidates[election_year == yr]
  votes_by_candidate[[as.character(yr)]] <- read_votes_year(yr, cand_yr)
  cat(sprintf("    %d candidate-location rows\n",
              nrow(votes_by_candidate[[as.character(yr)]])))
}
votes <- rbindlist(votes_by_candidate, fill = TRUE)
votes <- votes[votes > 0]
cat(sprintf("\nCandidate-location vote rows: %d\n\n", nrow(votes)))

# Candidate-profile outcomes.
votes[, candidate_votes_total := sum(votes), by = .(loc_id, election_year, DS_CARGO)]
votes[, vote_share_candidate := votes / candidate_votes_total]

profile <- votes[, .(
  candidate_votes = sum(votes, na.rm = TRUE),
  n_candidates_with_votes = uniqueN(NR_CANDIDATO),
  n_competitive_candidates_1pct = sum(vote_share_candidate >= 0.01, na.rm = TRUE),
  n_competitive_candidates_5pct = sum(vote_share_candidate >= 0.05, na.rm = TRUE),
  top_candidate_share = max(vote_share_candidate, na.rm = TRUE),
  top3_candidate_share = sum(head(sort(vote_share_candidate, decreasing = TRUE), 3),
                             na.rm = TRUE),
  elected_vote_share = sum(votes[elected == TRUE], na.rm = TRUE) / sum(votes, na.rm = TRUE),
  age_vote_weighted = sum(votes * age, na.rm = TRUE) /
    sum(votes[!is.na(age)], na.rm = TRUE),
  education_score_vote_weighted = sum(votes * education_score, na.rm = TRUE) /
    sum(votes[!is.na(education_score)], na.rm = TRUE),
  share_college = sum(votes[college_complete == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  share_low_education = sum(votes[low_education == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  share_security_occupation = sum(votes[security_occupation == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  share_public_admin_occupation = sum(votes[public_admin_occupation == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  share_female = sum(votes[female == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  share_black_pardo = sum(votes[black_pardo == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE)
), by = .(loc_id, election_year, DS_CARGO)]

for (cc in names(profile)) {
  if (is.numeric(profile[[cc]])) {
    profile[is.nan(get(cc)) | is.infinite(get(cc)), (cc) := NA_real_]
  }
}

fwrite(profile, file.path(DATA_DIR, "candidate_profile_by_location.csv"))
cat(sprintf("Wrote data/candidate_profile_by_location.csv (%d rows)\n",
            nrow(profile)))

# Party bloc outcomes from candidate-person votes.
votes[, SG_PARTIDO_STD := clean_text(SG_PARTIDO)]
votes_bloc <- merge(
  votes,
  party_bloc_table[, .(SG_PARTIDO_STD, bloc, ideology_score)],
  by = "SG_PARTIDO_STD",
  all.x = TRUE
)
party_coverage <- votes_bloc[, .(
  total_votes = sum(votes, na.rm = TRUE),
  classified_votes = sum(votes[!is.na(bloc)], na.rm = TRUE),
  unclassified_votes = sum(votes[is.na(bloc)], na.rm = TRUE),
  unclassified_parties = paste(sort(unique(SG_PARTIDO_STD[is.na(bloc)])),
                               collapse = "; ")
), by = .(election_year, DS_CARGO)]
party_coverage[, classified_share := classified_votes / total_votes]
setcolorder(party_coverage, c("election_year", "DS_CARGO", "total_votes",
                              "classified_votes", "unclassified_votes",
                              "classified_share", "unclassified_parties"))
fwrite(party_coverage, file.path(OUT_DIR,
                                 "tab93_party_classification_coverage.csv"))
cat("Wrote results/tab93_party_classification_coverage.csv\n")

bloc <- votes_bloc[!is.na(bloc), .(
  bloc_votes = sum(votes, na.rm = TRUE),
  total_candidate_votes = candidate_votes_total[1]
), by = .(loc_id, election_year, DS_CARGO, bloc)]
bloc[, bloc_share := bloc_votes / total_candidate_votes]
bloc_wide <- dcast(bloc, loc_id + election_year + DS_CARGO ~ bloc,
                   value.var = "bloc_share", fill = 0)
for (nm in c("Left", "Center", "Right")) {
  if (!nm %in% names(bloc_wide)) bloc_wide[, (nm) := 0]
}
setnames(bloc_wide, c("Left", "Center", "Right"),
         c("left_share", "center_share", "right_share"))
bloc_wide[, ideology_score_vote_weighted := right_share - left_share]
fwrite(bloc_wide, file.path(DATA_DIR, "party_bloc_by_location.csv"))
cat(sprintf("Wrote data/party_bloc_by_location.csv (%d rows)\n",
            nrow(bloc_wide)))

# PT versus PL/PR candidate-party vote shares.
votes_party <- copy(votes)
votes_party[, target_party := fcase(
  SG_PARTIDO_STD == "PT", "pt",
  SG_PARTIDO_STD %in% c("PL", "PR"), "pl_pr",
  default = NA_character_
)]
party_specific <- votes_party[!is.na(target_party), .(
  party_votes = sum(votes, na.rm = TRUE),
  total_candidate_votes = candidate_votes_total[1]
), by = .(loc_id, election_year, DS_CARGO, target_party)]
party_specific[, party_share := party_votes / total_candidate_votes]

party_specific_wide <- unique(votes[, .(loc_id, election_year, DS_CARGO)])
party_specific_wide <- merge(
  party_specific_wide,
  dcast(party_specific, loc_id + election_year + DS_CARGO ~ target_party,
        value.var = "party_share", fill = 0),
  by = c("loc_id", "election_year", "DS_CARGO"),
  all.x = TRUE
)
for (nm in c("pt", "pl_pr")) {
  if (!nm %in% names(party_specific_wide)) party_specific_wide[, (nm) := 0]
  party_specific_wide[is.na(get(nm)), (nm) := 0]
}
setnames(party_specific_wide, c("pt", "pl_pr"),
         c("pt_share", "pl_pr_share"))
party_specific_wide[, pl_pr_minus_pt_share := pl_pr_share - pt_share]
fwrite(party_specific_wide, file.path(DATA_DIR,
                                      "party_specific_by_location.csv"))
cat(sprintf("Wrote data/party_specific_by_location.csv (%d rows)\n\n",
            nrow(party_specific_wide)))

# Build CS-DID panels, following 70_main_results.R conventions.
dt_aptos <- fread(file.path(DATA_DIR, "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(DATA_DIR, "locais_votacao_treatment_annual.csv"))
dt_chg <- fread(file.path(DATA_DIR, "loc_faction_changes.csv"))
dt_loc2t <- fread(file.path(DATA_DIR, "loc_to_territory.csv"))

dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]
dt_loc2t[, loc_id := as.character(loc_id)]
dt_loc2t[, territory_id := as.integer(territory_id)]

map_gvar <- function(g) {
  ifelse(g == 0 | is.na(g), 2008,
         sapply(g, function(x) {
           ey <- elec_years[elec_years >= x]
           if (length(ey) == 0) max(elec_years) else min(ey)
         }))
}

loc_gvar <- dt_treat[, .(gvar_raw = gvar[1]), by = loc_id]
loc_gvar[, gvar_cs := map_gvar(gvar_raw)]

loc_faction_spec <- dt_treat[inside_controle == 1,
  .(faction_specific = faction_type_controle[1]), by = loc_id]
loc_faction_spec[faction_specific %in% c("Milicia", "MilÃ­cia"),
                 faction_specific := "Militia"]

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE
)
loc_info <- merge(loc_info, dt_loc2t, by = "loc_id", all.x = TRUE)
loc_info <- merge(loc_info, loc_faction_spec, by = "loc_id", all.x = TRUE)

analysis_dt <- merge(profile, bloc_wide,
                     by = c("loc_id", "election_year", "DS_CARGO"),
                     all.x = TRUE)
analysis_dt <- merge(analysis_dt, party_specific_wide,
                     by = c("loc_id", "election_year", "DS_CARGO"),
                     all.x = TRUE)
for (nm in c("pt_share", "pl_pr_share", "pl_pr_minus_pt_share")) {
  analysis_dt[is.na(get(nm)), (nm) := 0]
}
analysis_dt[, loc_id := as.character(loc_id)]
analysis_dt[, election_year := as.numeric(election_year)]

dt_faction <- merge(analysis_dt,
                    loc_info[, .(loc_id, gvar_cs, change_type,
                                 faction_specific, territory_id)],
                    by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                    by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

faction_locs <- unique(loc_info$loc_id)
never_locs <- setdiff(unique(analysis_dt$loc_id), faction_locs)
nt_info <- data.table(
  loc_id = never_locs,
  gvar_cs = 0L,
  change_type = "never_treated",
  faction_specific = NA_character_,
  territory_id = NA_integer_
)
loc_info_full <- rbind(
  loc_info[, .(loc_id, gvar_cs, change_type, faction_specific, territory_id)],
  nt_info,
  fill = TRUE
)
dt_full <- merge(analysis_dt, loc_info_full, by = "loc_id")
dt_full <- merge(dt_full, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)
dt_full <- dt_full[election_year %in% elec_years]
dt_full <- dt_full[!is.na(qt_aptos) & qt_aptos > 0]

run_csdid <- function(d_run, outcome, lbl, ctrl_group) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  n_locs <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)

  if (n_cohorts < 2 || n_locs < 20) {
    cat(sprintf("  %-65s SKIP\n", lbl))
    return(NULL)
  }

  tryCatch({
    att <- att_gt(
      yname = outcome,
      tname = "election_year",
      idname = "loc_num",
      gname = "gvar_cs",
      xformla = ~1,
      data = as.data.frame(d),
      base_period = "universal",
      control_group = ctrl_group,
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )

    agg <- aggte(att, type = "dynamic")
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))
    cat(sprintf("  %-65s ATT=%+.4f p=%.3f N=%d\n",
                lbl, agg$overall.att, p, n_locs))

    overall <- data.table(
      outcome = outcome,
      att = agg$overall.att,
      se = agg$overall.se,
      p_value = p,
      n_locs = n_locs,
      n_cohorts = n_cohorts
    )
    es <- data.table(
      outcome = outcome,
      event_time = agg$egt,
      att = agg$att.egt,
      se = agg$se.egt
    )
    list(overall = overall, es = es)
  }, error = function(e) {
    cat(sprintf("  %-65s ERROR: %s\n", lbl, substr(e$message, 1, 70)))
    NULL
  })
}

outcomes <- c(
  "elected_vote_share",
  "age_vote_weighted",
  "education_score_vote_weighted",
  "share_college",
  "share_low_education",
  "share_security_occupation",
  "share_public_admin_occupation",
  "share_female",
  "share_black_pardo",
  "n_competitive_candidates_1pct",
  "top_candidate_share",
  "top3_candidate_share",
  "left_share",
  "right_share",
  "ideology_score_vote_weighted",
  "pt_share",
  "pl_pr_share",
  "pl_pr_minus_pt_share"
)

specs <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug", filter_type = "stable_Drug")
)

all_overall <- list()
all_es <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))
  d_nyt <- dt_faction[change_type == sp$filter_type]
  d_nt <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]

  for (cargo in cargos) {
    for (oc in outcomes) {
      r <- run_csdid(d_nyt[DS_CARGO == cargo], oc,
                     sprintf("%s / %s / %s [NYT]", sp$name, cargo, oc),
                     "notyettreated")
      if (!is.null(r)) {
        r$overall[, `:=`(spec = sp$name, cargo = cargo, estimator = "NYT")]
        r$es[, `:=`(spec = sp$name, cargo = cargo, estimator = "NYT")]
        all_overall[[length(all_overall) + 1]] <- r$overall
        all_es[[length(all_es) + 1]] <- r$es
      }

      r <- run_csdid(d_nt[DS_CARGO == cargo], oc,
                     sprintf("%s / %s / %s [NT]", sp$name, cargo, oc),
                     "nevertreated")
      if (!is.null(r)) {
        r$overall[, `:=`(spec = sp$name, cargo = cargo, estimator = "NT")]
        r$es[, `:=`(spec = sp$name, cargo = cargo, estimator = "NT")]
        all_overall[[length(all_overall) + 1]] <- r$overall
        all_es[[length(all_es) + 1]] <- r$es
      }
    }
  }
}

tab_overall <- rbindlist(all_overall, fill = TRUE)
tab_es <- rbindlist(all_es, fill = TRUE)
setcolorder(tab_overall, c("spec", "cargo", "estimator", "outcome"))
setcolorder(tab_es, c("spec", "cargo", "estimator", "outcome"))

fwrite(tab_overall, file.path(OUT_DIR, "tab93_political_profile_overall.csv"))
fwrite(tab_es, file.path(OUT_DIR, "tab93_political_profile_es.csv"))

cat("\nWrote results/tab93_political_profile_overall.csv\n")
cat("Wrote results/tab93_political_profile_es.csv\n")
cat("DONE - 93_political_profile_outcomes.R\n")
