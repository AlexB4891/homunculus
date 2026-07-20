# homunculus 

> *A small model that learns from the process it replaces.*

`homunculus` is an R package that automates the **homologation** of categorical
variables across datasets. It replaces a manual, Excel-based copy-paste workflow
with a reproducible, auditable, GPU-accelerated pipeline: dictionary lookup
first, machine-learning fallback second.

The name comes from the idea of a small model that mimics a larger human
process — here, it learns from the manual matches analysts have already
confirmed and generalises from them.

---

## The problem

Raw survey and administrative data arrives with inconsistent category strings.
The same real-world entity can appear in dozens of forms:

| Raw value (`categoria_in`) | Canonical code | Label |
|---|---|---|
| `"PICHINCHA"` | `17` | Pichincha |
| `"Pich."` | `17` | Pichincha |
| `"1701"` | `17` | Pichincha |
| `"170150"` | `17` | Pichincha |
| `"17"` | `17` | Pichincha |

Homologation means reliably resolving all of those to `(17, "Pichincha")` —
regardless of how they were entered, which survey round they came from, or
which analyst processed them.

---

## Design principle

`homunculus` is a **registration engine, not a transformation engine.**

It reads raw values, resolves them, and **writes the resolved mappings into
PostgreSQL**. The actual replacement of strings with integer codes happens
downstream in the ETL, using those registered relationships. This keeps the
pipeline auditable and fully reversible at every step.

```
SOURCE TABLE + variable list
          │
          ▼
  ┌───────────────────┐
  │    homunculus     │  ← dictionary  +  GPU / ML model
  │  match & resolve  │
  └───────────────────┘
          │
          ▼
  CATEGORICAL RELATIONSHIPS   ← written to PostgreSQL
          │
          ▼
  ETL DOWNSTREAM STEPS
  (clean → summarise → aggregate)
          │
          ▼
  DATA CUBE
  (integer codes + labels, ready for analysis)
```

---

## Two-stage matching

### Stage 1 — Dictionary (CPU, deterministic)

1. **Exact match** — `categoria_in` matches a known pattern exactly
2. **Code completion** — truncated codes are padded and retried
3. **Fuzzy match** — Jaro-Winkler / Levenshtein distance below a configurable
   threshold

If confidence ≥ threshold → resolved. Method recorded as `"exact"` or
`"fuzzy"`.

### Stage 2 — ML model (GPU-accelerated)

When Stage 1 fails or confidence is too low:

1. **Text embedding** — raw string converted to a dense vector using a
   pretrained multilingual model running on an NVIDIA RTX via `torch` for R
2. **Nearest-neighbour search** — FAISS index over known dictionary patterns
3. **Classification head** — trained on the historical manual match log already
   in PostgreSQL

Every human-confirmed match becomes a new training example, so the model
improves over time.

---

## Infrastructure

```
┌──────────────────────────────────────────────────────────────────┐
│                         Proxmox Server                           │
│                                                                  │
│  ┌───────────────────────────┐   ┌────────────────────────────┐  │
│  │   Rocky Linux             │   │   Windows VM (GPU)         │  │
│  │                           │   │                            │  │
│  │   PostgreSQL              │   │   R + homunculus           │  │
│  │   - dictionaries          │◄──►   - torch (CUDA)           │  │
│  │   - metadata              │   │   - GPU text embeddings    │  │
│  │   - homologation log      │   │   - ML matching model      │  │
│  └───────────────────────────┘   └────────────────────────────┘  │
│                                          │ PCIe Passthrough       │
│                                     NVIDIA GeForce RTX            │
└──────────────────────────────────────────────────────────────────┘
```

PostgreSQL on Rocky Linux is the single source of truth. R reads from it,
processes with the GPU, and writes results back. Nothing important lives only
in R memory or local files.

---

## Installation

```r
# Development version from GitHub
# install.packages("devtools")
devtools::install_github("YOUR_USER/homunculus")
```

### System requirements

| Requirement | Notes |
|---|---|
| R ≥ 4.1 | Native pipe `\|>` required |
| PostgreSQL ≥ 13 | On a reachable host |
| NVIDIA GPU + CUDA | Stage 2 only; Stage 1 runs on CPU |
| `torch` for R | `install.packages("torch"); torch::install_torch()` |

---

## Usage

```r
library(homunculus)

# 1. Establish a database connection
con <- hom_connect(
  host     = Sys.getenv("PG_HOST"),
  dbname   = Sys.getenv("PG_DB"),
  user     = Sys.getenv("PG_USER"),
  password = Sys.getenv("PG_PASSWORD")
)

# 2. Run the homologation pipeline
homologate(
  data         = my_source_table,
  categoricals = c("provincia", "canton", "parroquia", "sector_economico"),
  fecha_ref    = "fecha_encuesta",   # column that selects the dictionary version
  con          = con,
  threshold    = 0.85                # minimum confidence to accept a match
)

# 3. Results are registered in PostgreSQL, not returned as a modified table.
#    Downstream ETL reads the resolved relationships from the DB.
```

### What gets written to the database

For each categorical variable processed, `homunculus` registers:

| Column | Description |
|---|---|
| `categoria_in` | Raw input value |
| `categoria_out` | Resolved canonical integer code |
| `categoria_desc` | Human-readable label |
| `method` | `exact`, `fuzzy`, `ml`, or `manual` |
| `score` | Confidence (0–1) |
| `dict_version` | Dictionary validity period applied |
| `processed_at` | Timestamp |

---

## Package structure

```
homunculus/
├── R/
│   ├── connect.R          # PostgreSQL connection helpers
│   ├── dictionary.R       # load and filter dictionary by date
│   ├── match_exact.R      # Stage 1a: exact matching
│   ├── match_fuzzy.R      # Stage 1b: fuzzy matching
│   ├── match_ml.R         # Stage 2: ML / GPU matching
│   ├── embed.R            # text embedding via torch
│   ├── pipeline.R         # orchestrates the full pipeline
│   ├── write_results.R    # write relationships to PostgreSQL
│   └── utils.R            # internal helpers (not exported)
├── tests/testthat/
│   ├── test-connect.R
│   ├── test-dictionary.R
│   ├── test-match-exact.R
│   ├── test-match-fuzzy.R
│   ├── test-match-ml.R
│   ├── test-embed.R
│   ├── test-pipeline.R
│   ├── test-write-results.R
│   ├── test-style.R       # enforces |> over %>% project-wide
│   └── fixtures/          # small .rds test data, never production
├── inst/
│   ├── sql/               # DDL reference files (not executed by package)
│   └── credentials/       # git-ignored; store .Renviron / keyring config here
└── data-raw/              # scripts to prepare internal reference data
```

---

## Development conventions

### Pipe style

The native pipe `|>` (R ≥ 4.1) is used exclusively. A `testthat` test and a
`lintr` rule enforce this automatically — any `%>%` in `R/` will fail
`devtools::check()`.

### Selective tidyverse imports

Inside the package, tidyverse functions are imported individually, never via
`library(tidyverse)`:

```r
#' @importFrom dplyr filter left_join mutate
#' @importFrom stringr str_to_lower str_trim
```

### Function design

Each function does one thing and is testable in isolation. All public functions
are documented with `roxygen2` and follow the signature pattern:

```r
#' @param x        character vector of raw categories
#' @param dict     tibble returned by \code{load_dictionary()}
#' @param method   one of "exact", "fuzzy"
#' @param threshold numeric, minimum confidence score (0–1)
#' @return tibble with columns: categoria_in, categoria_out,
#'   categoria_desc, score, method
#' @export
match_dictionary <- function(x, dict, method = "fuzzy", threshold = 0.8) { }
```

### Commit format

```
type(scope): short description

Types: feat  fix  test  docs  refactor  chore

Examples:
  feat(dictionary): add time-validity filter by fecha_referencia
  test(match-exact): add fixtures for Ecuador provincia codes
  fix(embed): handle NA inputs before GPU call
  docs(pipeline): update README with full usage example
```

### Branch model

```
main        ← stable, always passes R-CMD-check
develop     ← integration branch
feat/*      ← one branch per phase or feature
```

---

## Roadmap

| Phase | Module | Status |
|---|---|---|
| 0 | Package skeleton | ✅ done |
| 1 | PostgreSQL connection | ✅ done  |
| 2 | Dictionary loader with time-validity | 🔲 |
| 3 | Exact + fuzzy matching | 🔲 |
| 4 | Text normalisation | 🔲 |
| 5 | GPU embedding setup | 🔲 |
| 6 | ML matching model | 🔲 |
| 7 | Full pipeline with `\|>` | 🔲 |
| 8 | Results writer (PostgreSQL upserts) | 🔲 |
| 9 | Performance benchmarks | 🔲 |

---

## Credentials

Database credentials are **never** hardcoded. Store them in `.Renviron`:

```
PG_HOST=your.db.host
PG_DB=your_database
PG_USER=your_user
PG_PASSWORD=your_password
```

Then access with `Sys.getenv("PG_HOST")` etc. The `inst/credentials/`
directory is git-ignored and can hold a keyring config as an alternative.

---

## License

MIT © 2026 — see [`LICENSE`](LICENSE) for details.
