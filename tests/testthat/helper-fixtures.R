# tests/testthat/helper-fixtures.R

#' Cargar un fixture de prueba desde tests/testthat/fixtures/
#'
#' @param nombre character, nombre del archivo dentro de fixtures/ (ej. "dict_provincias.rds")
#' @return el objeto R guardado en el fixture
load_fixture <- function(nombre) {
  readRDS(testthat::test_path("fixtures", nombre))
}