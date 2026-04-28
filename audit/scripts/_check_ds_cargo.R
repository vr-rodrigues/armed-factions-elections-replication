suppressPackageStartupMessages(library(data.table))
dt <- fread("C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais/data/electoral_competition_measures.csv")
cat("Unique DS_CARGO values:\n")
print(unique(dt$DS_CARGO))
cat("\nCross-tab year x cargo:\n")
print(dt[, .N, by=.(election_year, DS_CARGO)][order(election_year, DS_CARGO)])
cat("\nFilter DS_CARGO == 'Prefeito' (no normalization):\n")
print(dt[DS_CARGO == "Prefeito", .N, by=election_year][order(election_year)])
cat("\nWith toTitleCase normalization:\n")
dt[, ds_norm := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
print(dt[ds_norm == "Prefeito", .N, by=election_year][order(election_year)])


