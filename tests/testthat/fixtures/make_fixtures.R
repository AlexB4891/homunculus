# Genera fixtures pequeñas para test-dictionary.R
# Nunca datos de producción reales — solo casos representativos

dict_provincias <- tibble::tribble(
  ~id_var, ~categoria_in,     ~categoria_in_desc, ~id_cat_out, ~categoria_out, ~categoria_desc, ~categoria_definicion, ~desde,       ~hasta,
  1L,      "PICHINCHA",       "Pichincha (raw)",  101L,        "17",           "Pichincha",     "provincia",           "2000-01-01", "2099-12-31",  # vigente
  1L,      "Pich.",           "Pichincha abrev",  101L,        "17",           "Pichincha",     "provincia",           "2000-01-01", "2099-12-31",  # vigente, mismo out
  2L,      "SANTO DOMINGO",   "cantón viejo",     102L,        "23_old",       "Santo Domingo (pre-2018)", "provincia", "2000-01-01", "2013-12-31",  # vencido
  3L,      "MANUFACTURA",     "sector viejo",     201L,        "C",            "Manufactura",   "sector_economico",    "2000-01-01", "2099-12-31"   # otro concepto
) |>
  dplyr::mutate(desde = as.Date(desde), hasta = as.Date(hasta))

saveRDS(dict_provincias, "tests/testthat/fixtures/dict_provincias.rds")

categorias_out_fixture <- tibble::tribble(
  ~categoria_definicion,
  "provincia",
  "sector_economico"
)

saveRDS(categorias_out_fixture, "tests/testthat/fixtures/categorias_out_fixture.rds")