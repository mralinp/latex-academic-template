# LaTeX Academic Template

Dockerized LaTeX templates you can compile with one command. No local LaTeX
install, no TeX Live setup, no fighting package managers -- just Docker and
`make`.

**[Browse the template gallery](https://alinaderiparizi.com/latex-academic-template/)**

## Why

Installing a full LaTeX distribution locally is slow, huge (multiple GB),
and drifts out of sync between machines. This repo instead pulls the
official [`texlive/texlive`](https://hub.docker.com/r/texlive/texlive)
Docker image and compiles everything inside a disposable container. Your
host machine only needs Docker and `make`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (with the Compose plugin,
  bundled with Docker Desktop) -- installed and running
- `make` (preinstalled on macOS and Linux)

That's it -- no LaTeX, no Python packages, nothing else to install.

## Get your own copy

This repo is a [GitHub template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template),
so you don't work directly in it -- you create your own copy first:

- **[Use this template](https://github.com/mralinp/latex-academic-template/generate)**
  (recommended) -- creates a brand-new, independent repository under your own
  account, with no shared history. Use this for your own resume, papers, or
  any document you'll own going forward.
- **[Fork](https://github.com/mralinp/latex-academic-template/fork)** instead
  if you plan to contribute a new template back to this repo via pull request.
- Or just `git clone` this repo directly if you only want to try it out
  locally without pushing anywhere.

## Quick start

```bash
git clone git@github.com:<you>/<your-new-repo>.git
cd <your-new-repo>

make list                     # see available templates
make build TEMPLATE=resume    # compiles templates/resume/main.tex
open templates/resume/main.pdf
```

The first build pulls the `texlive/texlive` image (a few GB, one-time). Every
build after that is fast, since the image is cached locally.

## Directory structure

```text
.
├── Makefile                  # build system -- see `make help`
├── docker-compose.yml        # defines the `latex` service/container
├── templates/                # one directory per template
│   ├── resume/
│   │   ├── main.tex
│   │   └── config.mk         # per-template metadata + build settings
│   ├── ieee-transactions/
│   └── springer-lncs/
├── documents/                 # your real documents, created with `make new`
├── scripts/
│   └── build_pages.py        # generates the GitHub Pages gallery
└── .github/workflows/        # CI build check + Pages deployment
```

## Available templates

| Template | Description |
| --- | --- |
| `resume` | Single-column resume/CV with a contact-icon header, education, publications, teaching, and experience sections. |
| `ieee-transactions` | Two-column IEEE journal/transactions paper skeleton (`IEEEtran` class). |
| `springer-lncs` | Springer Lecture Notes in Computer Science proceedings paper skeleton (`llncs` class). |

Run `make list` for the live, up-to-date list read directly from each
template's `config.mk`.

## Using the Makefile

Run `make help` at any time for the full, current list of targets. The
main ones:

| Command | What it does |
| --- | --- |
| `make list` | List all available templates |
| `make build TEMPLATE=resume` | Compile a template to `templates/resume/main.pdf` |
| `make build TEMPLATE=resume ENGINE=xelatex` | Compile with a specific engine (`pdflatex`, `xelatex`, `lualatex`) |
| `make build-all` | Compile every template (used by CI) |
| `make watch TEMPLATE=resume` | Recompile automatically on every save (`latexmk -pvc`) |
| `make compile FILE=documents/my-paper/main.tex` | Compile any `.tex` file directly, template or not |
| `make new NAME=my-cv TEMPLATE=resume` | Start a real document from a template, under `documents/` |
| `make add-template NAME=my-template` | Scaffold a brand new template under `templates/` |
| `make clean TEMPLATE=resume` | Remove build artifacts for one template |
| `make clean-all` | Remove build artifacts everywhere |
| `make shell TEMPLATE=resume` | Drop into a shell inside the container, in that template's directory |
| `make lint TEMPLATE=resume` | Lint with `chktex` |
| `make wordcount TEMPLATE=resume` | Word count with `texcount` |
| `make pages` | Build the Pages gallery locally into `./site` |
| `make pull` | Pull/update the `texlive/texlive` image |

Every template-scoped target reads defaults (engine, entry file, whether
`-shell-escape` is needed) from that template's `config.mk`, and any of them
can be overridden ad hoc on the command line, e.g.
`make build TEMPLATE=resume ENGINE=lualatex`.

## Starting a real document

Templates under `templates/` are meant to stay generic starting points. When
you want to actually write something, scaffold a working copy instead of
editing the template in place:

```bash
make new NAME=job-application-cv TEMPLATE=resume
make compile FILE=documents/job-application-cv/main.tex
```

This copies the template into `documents/job-application-cv/`, which you're
free to edit, version, or gitignore as you see fit -- it's your content, not
part of the template gallery.

## Adding a new template

Templates are just directories under `templates/` with two files:

1. `main.tex` -- the actual LaTeX source, self-contained (any class files it
   needs should come from the TeX Live distribution already bundled in the
   `texlive/texlive` image, not from loose files you'd otherwise have to vendor).
2. `config.mk` -- plain `KEY := value` lines read both by the Makefile and by
   the Pages-gallery script:

   ```make
   NAME := My Template
   DESCRIPTION := One or two sentences describing it, shown in the gallery.
   TAGS := tag1 tag2
   ENGINE := pdflatex   # or xelatex / lualatex
   MAIN := main.tex
   SHELL_ESCAPE := false
   ```

The fastest way to start one is:

```bash
make add-template NAME=ieee-conference
```

which scaffolds both files for you. Once `templates/<name>/main.tex` exists,
it's automatically picked up by `make list`, `make build-all`, and the Pages
gallery -- no other registration step needed.

## GitHub Pages

`scripts/build_pages.py` builds every template, renders a page-1 thumbnail
of each PDF, and generates a static gallery into `./site`. Run it locally
with `make pages`, or let CI do it: `.github/workflows/pages.yml` runs on
every push to `main` and deploys `./site` via GitHub's native Pages-from-Actions
flow.

One-time setup (already done for this repo): in **Settings → Pages**, set
**Source** to **GitHub Actions**. Note that GitHub Pages requires the
repository to be public on the free plan.

## Continuous integration

`.github/workflows/build.yml` compiles every template on every push and pull
request, so a template that fails to build gets caught before it merges.

## License

[MIT](LICENSE)
