# NOTA: estos tests construyen su propio `dict` inline en lugar de usar
# load_fixture("dict_provincias.rds") porque ese .rds vive en tu repo real
# y no está disponible en este entorno. Si tu fixture de Fase 2 ya cubre
# "PICHINCHA" -> "17", puedes reemplazar `dict_provincias()` de abajo por
# `load_fixture("dict_provincias.rds")` directamente.

dict_provincias <- function() {
  tibble::tibble(
    categoria_in = c("PICHINCHA", "GUAYAS"),
    categoria_out = c("17", "9"),
    categoria_desc = c("Pichincha", "Guayas"),
    categoria_definicion = "provincia",
    desde = as.Date("2014-01-01"),
    hasta = as.Date("2999-12-31")
  )
}

test_that("match_exact resolves a literal exact match", {
  dict <- dict_provincias()
  result <- match_exact("PICHINCHA", dict)
  
  expect_equal(result$categoria_out, "17")
  expect_equal(result$categoria_desc, "Pichincha")
  expect_equal(result$method, "exact")
  expect_equal(result$score, 1)
})

test_that("match_exact normalizes whitespace, case and accents", {
  dict <- dict_provincias()
  
  expect_equal(match_exact("  pichincha  ", dict)$categoria_out, "17")
  expect_equal(match_exact("Pichincha", dict)$categoria_out, "17")
  expect_equal(match_exact("PICHÍNCHA", dict)$categoria_out, "17")
})

test_that("match_exact returns NA with method = 'exact' when no match found", {
  dict <- dict_provincias()
  result <- match_exact("XXXXX", dict)
  
  expect_true(is.na(result$categoria_out))
  expect_true(is.na(result$categoria_desc))
  expect_true(is.na(result$score))
  expect_equal(result$method, "exact")
})

test_that("match_exact returns categoria_out as character, never integer", {
  dict <- dict_provincias()
  result <- match_exact("PICHINCHA", dict)
  
  expect_type(result$categoria_out, "character")
})

test_that("match_exact handles an empty dict (new-concept / bootstrap case)", {
  empty_dict <- dict_provincias()[0, ]
  result <- match_exact("PICHINCHA", empty_dict)
  
  expect_true(is.na(result$categoria_out))
  expect_equal(result$method, "exact")
  expect_equal(nrow(result), 1)
})

test_that("match_exact handles an empty input vector", {
  dict <- dict_provincias()
  result <- match_exact(character(0), dict)
  
  expect_equal(nrow(result), 0)
  expect_named(
    result,
    c("categoria_in", "categoria_out", "categoria_desc", "score", "method")
  )
})

test_that("match_exact processes a mixed vector of hits and misses together", {
  dict <- dict_provincias()
  result <- match_exact(c("PICHINCHA", "XXXXX", "guayas"), dict)
  
  expect_equal(result$categoria_out, c("17", NA, "9"))
  expect_equal(result$method, rep("exact", 3))
})

test_that("match_exact warns when the dictionary has conflicting entries", {
  dict <- tibble::tibble(
    categoria_in = c("A", "a"),
    categoria_out = c("1", "2"),
    categoria_desc = c("Uno", "Dos"),
    categoria_definicion = "test",
    desde = as.Date("2000-01-01"),
    hasta = as.Date("2999-01-01")
  )
  
  expect_warning(match_exact("A", dict), "distinct keys affected")
})

test_that("match_exact keeps first occurrence deterministically on conflict", {
  dict <- tibble::tibble(
    categoria_in = c("A", "a"),
    categoria_out = c("1", "2"),
    categoria_desc = c("Uno", "Dos"),
    categoria_definicion = "test",
    desde = as.Date("2000-01-01"),
    hasta = as.Date("2999-01-01")
  )
  
  result <- suppressWarnings(match_exact("A", dict))
  expect_equal(result$categoria_out, "1")
})