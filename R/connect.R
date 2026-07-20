# Fase 1 — Conexión a PostgreSQL
# homunculus::connect

#' Carga la configuración de base de datos
#'
#' Lee los parámetros no secretos (host, port, dbname) desde `config.yml`
#' y las credenciales secretas (user, password) desde variables de entorno
#' definidas en `.Renviron`. Nunca se deben commitear credenciales reales.
#'
#' @param config_path ruta al archivo config.yml
#' @param which nombre del bloque de configuración a usar
#'   (ej. "default", "production"). Por defecto usa la variable de entorno
#'   `R_CONFIG_ACTIVE`, o "default" si no está definida.
#' @return una lista con host, port, dbname, user, password
#' @importFrom config get
#' @keywords internal
hom_db_config <- function(config_path = "config.yml",
                          which = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  
  cfg <- config::get(config = which, file = config_path)
  
  required <- c("host", "port", "dbname")
  faltantes <- setdiff(required, names(cfg))
  if (length(faltantes) > 0) {
    stop(
      "config.yml no tiene el/los campo(s) requerido(s): ",
      paste(faltantes, collapse = ", "),
      call. = FALSE
    )
  }
  
  user     <- Sys.getenv("HOMUNCULUS_PG_USER")
  password <- Sys.getenv("HOMUNCULUS_PG_PASSWORD")
  
  if (identical(user, "") || identical(password, "")) {
    stop(
      "HOMUNCULUS_PG_USER y HOMUNCULUS_PG_PASSWORD deben estar definidos ",
      "en tu .Renviron. Ver .Renviron.example en la raíz del paquete.",
      call. = FALSE
    )
  }
  
  list(
    host     = cfg$host,
    port     = cfg$port,
    dbname   = cfg$dbname,
    user     = user,
    password = password
  )
}

#' Conectar a la base de datos de homunculus (pool)
#'
#' Abre un pool de conexiones con \pkg{pool} + \pkg{RPostgres}. Se usa
#' pooling (en vez de una conexión DBI simple) porque \code{homunculus} se
#' expondrá eventualmente detrás de una API (ej. \pkg{plumber}), donde
#' múltiples requests concurrentes necesitan tomar/devolver conexiones sin
#' pagar el costo de un handshake TCP + auth por cada llamada.
#'
#' @param config_path ruta al config.yml
#' @param which bloque de configuración ("default", "production", ...)
#' @param ... argumentos adicionales pasados a \code{RPostgres::Postgres()}
#' @return un objeto \code{pool::Pool}
#' @export
hom_connect <- function(config_path = "config.yml",
                        which = Sys.getenv("R_CONFIG_ACTIVE", "default"),
                        ...) {
  
  cfg <- hom_db_config(config_path = config_path, which = which)
  
  pool::dbPool(
    drv      = RPostgres::Postgres(),
    host     = cfg$host,
    port     = cfg$port,
    dbname   = cfg$dbname,
    user     = cfg$user,
    password = cfg$password,
    ...
  )
}

#' Cerrar el pool de conexiones de homunculus
#'
#' @param pool un objeto \code{pool::Pool} devuelto por \code{hom_connect()}
#' @export
hom_disconnect <- function(pool) {
  pool::poolClose(pool)
  invisible(TRUE)
}

#' Verificar que una conexión/pool está viva
#'
#' @param con un \code{pool::Pool} o una conexión DBI
#' @return lógico: TRUE si responde correctamente
#' @export
hom_ping <- function(con) {
  tryCatch({
    identical(DBI::dbGetQuery(con, "SELECT 1 AS ok")$ok, 1L)
  }, error = function(e) FALSE)
}