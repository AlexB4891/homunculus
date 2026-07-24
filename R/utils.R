#' Normalize text for matching
#'
#' Trims whitespace, lowercases, and strips diacritics (accents, ene) so that
#' e.g. "PICHINCHA", "Pichincha", " pichincha " all reduce to the same
#' comparable form.
#'
#' This is a **minimal** normalization step used internally by
#' \code{match_exact()} (Stage 1a). It never touches the original
#' \code{categoria_in} values stored anywhere -- normalization happens only
#' in memory, at comparison time. Fase 4 will extend this function with
#' fuller encoding/locale handling (edge cases in mixed encodings, etc.);
#' it should be *extended*, not duplicated, when that happens.
#'
#' @param x character vector
#' @return character vector, same length as \code{x}
#' @keywords internal
#' @importFrom stringi stri_trans_general stri_trans_tolower
normalize_text <- function(x) {
  # NOTE: base::tolower() depends on the system locale and silently fails
  # to lowercase accented characters under a "C" locale (e.g. "Í" stays
  # "Í"). If accent-stripping ran afterwards it would then produce an
  # uppercase ASCII letter ("I") instead of "i". stringi's functions are
  # locale-independent Unicode operations, so we use those instead and
  # strip accents *before* lowercasing to sidestep the issue entirely.
  x |>
    trimws() |>
    stringi::stri_trans_general("Latin-ASCII") |>
    stringi::stri_trans_tolower()
}