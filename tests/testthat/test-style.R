# Enforces native pipe |> project-wide — no magrittr %>% allowed.

test_that("no legacy %>% pipe is used anywhere in R/ source files", {
  r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  matches <- lapply(r_files, function(f) {
    lines <- readLines(f, warn = FALSE)
    grep("%>%", lines, value = TRUE, fixed = TRUE)
  })
  found <- unlist(matches)
  expect_length(
    found, 0L
  )
})
