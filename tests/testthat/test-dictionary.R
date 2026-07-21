test_that("load_dictionary devuelve solo filas vigentes en fecha_referencia", {
  dict <- load_fixture("dict_provincias.rds")
  
  resultado <- load_dictionary(
    categoria_definicion = "provincia",
    fecha_referencia = as.Date("2020-01-01"),
    diccionario = dict
  )
  
  expect_equal(nrow(resultado), 2L)
  expect_setequal(resultado$categoria_in, c("PICHINCHA", "Pich."))
})

test_that("load_dictionary excluye categorias_out vencidas para la fecha", {
  dict <- load_fixture("dict_provincias.rds")
  
  resultado <- load_dictionary(
    categoria_definicion = "provincia",
    fecha_referencia = as.Date("2020-01-01"),
    diccionario = dict
  )
  
  expect_false("SANTO DOMINGO" %in% resultado$categoria_in)
})

test_that("load_dictionary incluye la fila vencida si la fecha_referencia cae dentro de su vigencia", {
  dict <- load_fixture("dict_provincias.rds")
  
  resultado <- load_dictionary(
    categoria_definicion = "provincia",
    fecha_referencia = as.Date("2010-06-01"),
    diccionario = dict
  )
  
  expect_true("SANTO DOMINGO" %in% resultado$categoria_in)
})

test_that("load_dictionary no mezcla conceptos distintos", {
  dict <- load_fixture("dict_provincias.rds")
  
  resultado <- load_dictionary(
    categoria_definicion = "provincia",
    fecha_referencia = as.Date("2020-01-01"),
    diccionario = dict
  )
  
  expect_false("MANUFACTURA" %in% resultado$categoria_in)
})

test_that("is_new_concept detecta un concepto inexistente", {
  cat_out <- load_fixture("categorias_out_fixture.rds")
  
  expect_true(is_new_concept(
    categoria_definicion = "nivel_educativo",
    categorias_out = cat_out
  ))
})

test_that("is_new_concept reconoce un concepto ya existente", {
  cat_out <- load_fixture("categorias_out_fixture.rds")
  
  expect_false(is_new_concept(
    categoria_definicion = "provincia",
    categorias_out = cat_out
  ))
})