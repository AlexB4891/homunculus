#' Match categories against the homologation dictionary (Stage 1a: exact)
#'
#' Compares each raw category in \code{x} against \code{dict$categoria_in}
#' using a normalized (trimmed, lowercased, accent-stripped) exact match --
#' see \code{normalize_text()}. This is deliberately narrow: it does not
#' attempt fuzzy matching. Unresolved values are returned with
#' \code{categoria_out = NA} and \code{method = "exact"}, signaling to the
#' pipeline that Stage 1a was tried and failed, so Stage 1b
#' (\code{match_fuzzy()}) should be attempted next.
#'
#' Note on "new concept" / bootstrap cases: this function does not know
#' or care whether \code{categoria_definicion} is new. If \code{dict} has
#' 0 rows (e.g. because \code{load_dictionary()} returned nothing for a
#' brand-new concept), every input in \code{x} simply comes back
#' unresolved, same as any other failed lookup. The bootstrap logic
#' (identity copy \code{categoria_out <- categoria_in} for new concepts)
#' belongs in \code{pipeline.R} (Fase 7), upstream of this function.
#'
#' @param x character vector of raw categories (typically unique values of
#'   the column declared as categorical for a given \code{categoria_definicion})
#' @param dict tibble returned by \code{load_dictionary()}, already filtered
#'   by \code{categoria_definicion} and \code{fecha_referencia}. Must contain
#'   at least columns \code{categoria_in}, \code{categoria_out},
#'   \code{categoria_desc}.
#' @return tibble with columns:
#'   \itemize{
#'     \item \code{categoria_in} -- original, unmodified value from \code{x}
#'     \item \code{categoria_out} -- character, NA if unresolved (kept as
#'       character to match the VARCHAR(255) column in Postgres; no cast to
#'       integer happens here)
#'     \item \code{categoria_desc} -- character, NA if unresolved
#'     \item \code{score} -- 1 if matched, NA if not
#'     \item \code{method} -- always \code{"exact"}, whether or not a match
#'       was found
#'   }
#' @export
#' @importFrom tibble tibble
match_exact <- function(x, dict) {
  if (length(x) == 0) {
    return(tibble::tibble(
      categoria_in = character(0),
      categoria_out = character(0),
      categoria_desc = character(0),
      score = numeric(0),
      method = character(0)
    ))
  }
  
  if (nrow(dict) == 0) {
    return(tibble::tibble(
      categoria_in = x,
      categoria_out = NA_character_,
      categoria_desc = NA_character_,
      score = NA_real_,
      method = "exact"
    ))
  }
  
  # Build a lookup keyed on normalized categoria_in. If the dictionary
  # contains duplicate normalized keys that map to *different*
  # categoria_out values, that's a data quality issue upstream (conflicting
  # manual matches, dirty dictionary rows) -- we keep the first occurrence
  # so the function still returns a deterministic result, but we warn
  # loudly instead of silently picking one with no signal to the caller.
  dict_norm <- dict
  dict_norm$.norm_key <- normalize_text(dict_norm$categoria_in)
  
  dupe_keys <- unique(dict_norm$.norm_key[duplicated(dict_norm$.norm_key)])
  if (length(dupe_keys) > 0) {
    ambiguous <- dict_norm[dict_norm$.norm_key %in% dupe_keys, ]
    conflicting <- vapply(
      split(ambiguous$categoria_out, ambiguous$.norm_key),
      function(out) length(unique(out)) > 1,
      logical(1)
    )
    if (any(conflicting)) {
      warning(
        "match_exact(): dictionary has normalized categoria_in values ",
        "mapping to different categoria_out (", sum(conflicting),
        " distinct keys affected). Keeping first occurrence per key -- ",
        "review dictionary for conflicts."
      )
    }
  }
  
  lookup <- dict_norm[!duplicated(dict_norm$.norm_key), ]
  
  x_norm <- normalize_text(x)
  match_idx <- match(x_norm, lookup$.norm_key)
  
  tibble::tibble(
    categoria_in = x,
    categoria_out = as.character(lookup$categoria_out[match_idx]),
    categoria_desc = as.character(lookup$categoria_desc[match_idx]),
    score = ifelse(is.na(match_idx), NA_real_, 1),
    method = "exact"
  )
}