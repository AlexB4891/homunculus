#' Cargar diccionario de homologación vigente para un concepto
#'
#' @param con conexión DBI activa (o NULL si se usa `diccionario` de fixture)
#' @param categoria_definicion character, concepto homologado (ej. "provincia")
#' @param fecha_referencia Date/POSIXct, fecha para validar vigencia contra categorias_out
#' @param diccionario tibble opcional con columnas de categorias_in + categorias_out
#'   ya unidas (mismo formato que retorna la query), usado en tests sin DB real
#'
#' @return tibble: id_var, categoria_in, categoria_in_desc, id_cat_out,
#'   categoria_out, categoria_desc, categoria_definicion
#' @importFrom dplyr filter
#' @importFrom glue glue_sql
#' @importFrom DBI dbGetQuery
#' @export
load_dictionary <- function(con = NULL, categoria_definicion,
                            fecha_referencia, diccionario = NULL) {
  
  if (!is.null(con)) {
    qry <- glue::glue_sql("
      SELECT
        cin.id_var,
        cin.categoria_in,
        cin.categoria_in_desc,
        cin.id_cat_out,
        cout.categoria_out,
        cout.categoria_desc,
        cout.categoria_definicion,
        cout.desde,
        cout.hasta
      FROM categorias_in cin
      INNER JOIN categorias_out cout
        ON cin.id_cat_out = cout.id_cat_out
      WHERE cout.categoria_definicion = {categoria_definicion}
        AND {fecha_referencia} BETWEEN cout.desde AND cout.hasta
    ", .con = con)
    
    dict <- DBI::dbGetQuery(con, qry)
  } else {
    dict <- diccionario |>
      dplyr::filter(
        .data$categoria_definicion == .env$categoria_definicion,
        .env$fecha_referencia >= .data$desde,
        .env$fecha_referencia <= .data$hasta
      )
  }
  
  tibble::as_tibble(dict)
}

#' Verificar si un concepto homologado ya existe
#'
#' Distingue "concepto nuevo" (dispara modo bootstrap in = out) de
#' "concepto existente pero sin vigencia para la fecha consultada".
#'
#' @param con conexión DBI activa (o NULL si se usa `categorias_out` de fixture)
#' @param categoria_definicion character, concepto homologado a verificar
#' @param categorias_out tibble opcional con la columna categoria_definicion,
#'   usado en tests sin DB real
#'
#' @return logical, TRUE si el concepto es nuevo (no existe en ninguna fecha)
#' @importFrom glue glue_sql
#' @importFrom DBI dbGetQuery
#' @export
is_new_concept <- function(con = NULL, categoria_definicion, categorias_out = NULL) {
  
  if (!is.null(con)) {
    qry <- glue::glue_sql("
      SELECT EXISTS (
        SELECT 1 FROM categorias_out
        WHERE categoria_definicion = {categoria_definicion}
      ) AS existe
    ", .con = con)
    
    existe <- DBI::dbGetQuery(con, qry)$existe
  } else {
    existe <- categoria_definicion %in% categorias_out$categoria_definicion
  }
  
  !isTRUE(existe)
}