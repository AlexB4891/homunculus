# Tests for connect.R
# usethis::use_test("connect")

test_that("hom_db_config falla si config.yml no tiene campos requeridos", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines('default:\n  host: "localhost"\n', tmp)
  
  withr::local_envvar(
    HOMUNCULUS_PG_USER = "u",
    HOMUNCULUS_PG_PASSWORD = "p"
  )
  
  expect_error(
    hom_db_config(config_path = tmp),
    "campo\\(s\\) requerido\\(s\\)"
  )
})

test_that("hom_db_config falla si faltan credenciales en .Renviron", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(
    'default:\n  host: "localhost"\n  port: 5432\n  dbname: "x"\n',
    tmp
  )
  
  withr::local_envvar(
    HOMUNCULUS_PG_USER = "",
    HOMUNCULUS_PG_PASSWORD = ""
  )
  
  expect_error(
    hom_db_config(config_path = tmp),
    "deben estar definidos"
  )
})

test_that("hom_db_config retorna la lista correcta cuando todo está bien", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(
    'default:\n  host: "localhost"\n  port: 5432\n  dbname: "x"\n',
    tmp
  )
  
  withr::local_envvar(
    HOMUNCULUS_PG_USER = "u",
    HOMUNCULUS_PG_PASSWORD = "p"
  )
  
  cfg <- hom_db_config(config_path = tmp)
  expect_equal(cfg$host, "localhost")
  expect_equal(cfg$port, 5432)
  expect_equal(cfg$dbname, "x")
  expect_equal(cfg$user, "u")
  expect_equal(cfg$password, "p")
})

test_that("hom_connect + hom_ping funcionan contra una BD real (skip por defecto)", {
  skip_if_not(
    identical(Sys.getenv("HOMUNCULUS_TEST_LIVE_DB"), "true"),
    "Define HOMUNCULUS_TEST_LIVE_DB=true para correr este test contra tu Postgres real"
  )
  
  con <- hom_connect()
  on.exit(hom_disconnect(con), add = TRUE)
  expect_true(hom_ping(con))
})