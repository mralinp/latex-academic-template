#!/usr/bin/env bash
# create-latex-app -- scaffold a new, standalone, Docker-buildable LaTeX
# project in one command. No local LaTeX install needed, only Docker.
#
# Run it directly after cloning this repo:
#   ./create-latex-app.sh
#
# Or with zero setup, from anywhere:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/mralinp/latex-academic-template/main/create-latex-app.sh)"
#
# Non-interactive usage:
#   ./create-latex-app.sh my-cv --template resume
#   ./create-latex-app.sh my-paper --zip ~/Downloads/overleaf-project.zip
#   ./create-latex-app.sh my-paper --git https://git.overleaf.com/xxxxxxxxxxxx

if [ -z "${BASH_VERSION:-}" ]; then
  echo "create-latex-app requires bash. Try: bash create-latex-app.sh" >&2
  exit 1
fi

set -u

REPO_GIT_URL="https://github.com/mralinp/latex-academic-template.git"
REPO_HTML_URL="https://github.com/mralinp/latex-academic-template"

# When piped through `curl ... | bash`, stdin is consumed by the pipe itself,
# so interactive prompts below would fail silently. Re-attach the real
# terminal when one is available so prompts still work either way.
if [ ! -t 0 ]; then
  { exec < /dev/tty; } 2>/dev/null || true
fi

if [ -t 1 ]; then
  BOLD=$(tput bold 2>/dev/null || true); RESET=$(tput sgr0 2>/dev/null || true)
  GREEN=$(tput setaf 2 2>/dev/null || true); BLUE=$(tput setaf 4 2>/dev/null || true)
  RED=$(tput setaf 1 2>/dev/null || true); YELLOW=$(tput setaf 3 2>/dev/null || true)
else
  BOLD=""; RESET=""; GREEN=""; BLUE=""; RED=""; YELLOW=""
fi

step() { printf "%s\n" "${BLUE}==>${RESET} $*"; }
ok()   { printf "%s\n" "${GREEN}v${RESET} $*"; }
warn() { printf "%s\n" "${YELLOW}!${RESET} $*" >&2; }
fail() { printf "%s\n" "${RED}x${RESET} $*" >&2; exit 1; }

TMP_DIR=""
SCRATCH_TMP=""
PROJECT_DIR_CREATED=""

cleanup() {
  local exit_code="${1:-0}"
  [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
  [ -n "$SCRATCH_TMP" ] && rm -rf "$SCRATCH_TMP"
  if [ "$exit_code" -ne 0 ] && [ -n "$PROJECT_DIR_CREATED" ] && [ -d "$PROJECT_DIR_CREATED" ]; then
    rm -rf "$PROJECT_DIR_CREATED"
    warn "Removed incomplete project directory '$PROJECT_DIR_CREATED'."
  fi
}
trap 'cleanup $?' EXIT

print_usage() {
  cat <<EOF
Usage: create-latex-app.sh [name] [options]

Options:
  --template NAME     Start from a gallery template (resume, ieee-transactions, springer-lncs, ...)
  --zip PATH          Import a local .zip project (e.g. downloaded from Overleaf)
  --git URL           Import from a git URL (e.g. an Overleaf git project)
  --engine ENGINE     pdflatex (default), xelatex, or lualatex
  --shell-escape      Enable -shell-escape (needed by packages like minted)
  --no-build          Scaffold only; don't offer to build it right away
  -h, --help          Show this help

With no options, you'll be prompted interactively for everything.
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
PROJECT_NAME=""
MODE=""
TEMPLATE=""
ZIP_PATH=""
GIT_URL=""
ENGINE_OVERRIDE=""
SHELL_ESCAPE_OVERRIDE=""
NO_BUILD="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --template) MODE="template"; TEMPLATE="${2:-}"; shift 2 ;;
    --zip) MODE="zip"; ZIP_PATH="${2:-}"; shift 2 ;;
    --git) MODE="git"; GIT_URL="${2:-}"; shift 2 ;;
    --engine) ENGINE_OVERRIDE="${2:-}"; shift 2 ;;
    --shell-escape) SHELL_ESCAPE_OVERRIDE="true"; shift ;;
    --no-build) NO_BUILD="true"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    -*) fail "Unknown option: $1 (see --help)" ;;
    *) PROJECT_NAME="$1"; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
command -v git >/dev/null 2>&1 || fail "git is required. Install it from https://git-scm.com/downloads and try again."
command -v docker >/dev/null 2>&1 || fail "Docker is required. Install Docker Desktop from https://docs.docker.com/get-docker/ and try again."
if ! docker info >/dev/null 2>&1; then
  fail "Docker is installed but doesn't seem to be running. Start Docker Desktop and try again."
fi

# ---------------------------------------------------------------------------
# Are we already sitting inside a clone of latex-academic-template?
# ---------------------------------------------------------------------------
LOCAL_SOURCE=""
if [ -f "./Makefile" ] && [ -d "./templates" ] && [ -f "./scaffold/Makefile" ]; then
  LOCAL_SOURCE="$(pwd)"
fi

resolve_source() {
  if [ -n "$LOCAL_SOURCE" ]; then
    SOURCE_DIR="$LOCAL_SOURCE"
    return
  fi
  step "Fetching latex-academic-template..."
  TMP_DIR="$(mktemp -d)"
  if ! git clone --depth 1 -q "$REPO_GIT_URL" "$TMP_DIR" >/dev/null 2>&1; then
    fail "Could not clone $REPO_GIT_URL. Check your network connection and try again."
  fi
  SOURCE_DIR="$TMP_DIR"
}

verify_source() {
  if [ ! -f "$SOURCE_DIR/scaffold/Makefile" ] || [ ! -f "$SOURCE_DIR/docker-compose.yml" ] || [ ! -f "$SOURCE_DIR/.gitignore" ]; then
    fail "The template source at $SOURCE_DIR looks incomplete. Please try again, or report this at $REPO_HTML_URL/issues."
  fi
}

read_config_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  grep -E "^${key}[[:space:]]*:?=" "$file" 2>/dev/null | head -n1 | sed -E "s/^${key}[[:space:]]*:?=[[:space:]]*//"
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
prompt_project_name() {
  while [ -z "$PROJECT_NAME" ]; do
    read -r -p "Project name: " PROJECT_NAME
  done
}

validate_project_name() {
  case "$PROJECT_NAME" in
    */*) fail "Project name can't contain '/'. cd to the parent directory first." ;;
    "") fail "Project name can't be empty." ;;
  esac
  if [ -e "$PROJECT_NAME" ]; then
    fail "'$PROJECT_NAME' already exists here. Choose a different name or remove it first."
  fi
}

prompt_mode() {
  [ -n "$MODE" ] && return
  echo "How do you want to start?"
  local options=("Pick a template from the gallery" "Import a local .zip project (e.g. from Overleaf)" "Import from a git URL (e.g. an Overleaf project)")
  local PS3="Choose 1-3: "
  local opt
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) MODE="template"; break ;;
      2) MODE="zip"; break ;;
      3) MODE="git"; break ;;
      *) echo "Please enter 1, 2, or 3." ;;
    esac
  done
}

prompt_template() {
  [ -n "$TEMPLATE" ] && return
  local names=()
  local labels=()
  local d n display
  for d in "$SOURCE_DIR"/templates/*/; do
    [ -f "$d/main.tex" ] || continue
    n="$(basename "$d")"
    display="$(read_config_value "$d/config.mk" NAME)"
    [ -n "$display" ] || display="$n"
    names+=("$n")
    labels+=("$n -- $display")
  done
  [ "${#names[@]}" -gt 0 ] || fail "No templates found in $SOURCE_DIR/templates"
  echo "Choose a template:"
  local PS3="Choose 1-${#names[@]}: "
  local choice
  select choice in "${labels[@]}"; do
    if [ -n "${choice:-}" ] 2>/dev/null && [ "$REPLY" -ge 1 ] 2>/dev/null && [ "$REPLY" -le "${#names[@]}" ] 2>/dev/null; then
      TEMPLATE="${names[$((REPLY-1))]}"
      break
    fi
    echo "Please enter a number between 1 and ${#names[@]}."
  done
}

prompt_zip_path() {
  while [ -z "$ZIP_PATH" ]; do
    read -r -e -p "Path to your .zip project: " ZIP_PATH
  done
}

prompt_git_url() {
  while [ -z "$GIT_URL" ]; do
    read -r -p "Git URL (e.g. an Overleaf project's git URL): " GIT_URL
  done
}

# ---------------------------------------------------------------------------
# Populate project content
# ---------------------------------------------------------------------------
ENGINE="pdflatex"
SHELL_ESCAPE_VAL="false"
MAIN_FILE="main.tex"

detect_main_tex() {
  local dir="$1"
  local found=""
  found="$(find "$dir" -iname "main.tex" 2>/dev/null | head -n1 || true)"
  if [ -z "$found" ]; then
    local f
    while IFS= read -r f; do
      if grep -q '\\documentclass' "$f" 2>/dev/null && grep -q '\\begin{document}' "$f" 2>/dev/null; then
        found="$f"
        break
      fi
    done < <(find "$dir" -iname "*.tex" 2>/dev/null)
  fi
  [ -z "$found" ] && { echo ""; return; }
  echo "${found#"$dir"/}"
}

flatten_single_dir() {
  local dir="$1"
  local entries=("$dir"/*)
  if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
    local inner="${entries[0]}"
    local tmp2
    tmp2="$(mktemp -d)"
    mv "$inner"/* "$tmp2"/ 2>/dev/null || true
    mv "$inner"/.[!.]* "$tmp2"/ 2>/dev/null || true
    rm -rf "$inner"
    mv "$tmp2"/* "$dir"/ 2>/dev/null || true
    mv "$tmp2"/.[!.]* "$dir"/ 2>/dev/null || true
    rm -rf "$tmp2"
  fi
}

populate_template() {
  local project_dir="$1"
  local tdir="$SOURCE_DIR/templates/$TEMPLATE"
  [ -d "$tdir" ] || fail "Template '$TEMPLATE' not found. Available: $(ls "$SOURCE_DIR/templates" | tr '\n' ' ')"
  ENGINE="$(read_config_value "$tdir/config.mk" ENGINE)"; [ -n "$ENGINE" ] || ENGINE="pdflatex"
  SHELL_ESCAPE_VAL="$(read_config_value "$tdir/config.mk" SHELL_ESCAPE)"; [ -n "$SHELL_ESCAPE_VAL" ] || SHELL_ESCAPE_VAL="false"
  MAIN_FILE="$(read_config_value "$tdir/config.mk" MAIN)"; [ -n "$MAIN_FILE" ] || MAIN_FILE="main.tex"
  cp -R "$tdir"/. "$project_dir"/
  rm -f "$project_dir/config.mk"
}

populate_zip() {
  local project_dir="$1"
  command -v unzip >/dev/null 2>&1 || fail "unzip is required to import a .zip project. Install it and try again."
  ZIP_PATH="${ZIP_PATH/#\~/$HOME}"
  [ -f "$ZIP_PATH" ] || fail "Zip file not found: $ZIP_PATH"
  SCRATCH_TMP="$(mktemp -d)"
  if ! unzip -q "$ZIP_PATH" -d "$SCRATCH_TMP"; then
    fail "Could not extract $ZIP_PATH -- is it a valid .zip file?"
  fi
  flatten_single_dir "$SCRATCH_TMP"
  cp -R "$SCRATCH_TMP"/. "$project_dir"/
  rm -rf "$SCRATCH_TMP"; SCRATCH_TMP=""
  MAIN_FILE="$(detect_main_tex "$project_dir")"
  if [ -z "$MAIN_FILE" ]; then
    warn "Could not auto-detect a main .tex file -- set MAIN in Makefile by hand."
    MAIN_FILE="main.tex"
  fi
}

populate_git() {
  local project_dir="$1"
  SCRATCH_TMP="$(mktemp -d)"
  if ! git clone --depth 1 -q "$GIT_URL" "$SCRATCH_TMP" >/dev/null 2>&1; then
    fail "Could not clone $GIT_URL -- check the URL and your network connection."
  fi
  rm -rf "$SCRATCH_TMP/.git"
  cp -R "$SCRATCH_TMP"/. "$project_dir"/
  rm -rf "$SCRATCH_TMP"; SCRATCH_TMP=""
  MAIN_FILE="$(detect_main_tex "$project_dir")"
  if [ -z "$MAIN_FILE" ]; then
    warn "Could not auto-detect a main .tex file -- set MAIN in Makefile by hand."
    MAIN_FILE="main.tex"
  fi
}

scaffold_common() {
  local project_dir="$1"

  if [ -f "$project_dir/Makefile" ]; then
    mv "$project_dir/Makefile" "$project_dir/Makefile.orig"
    warn "Project already had a Makefile -- preserved as Makefile.orig"
  fi
  cp "$SOURCE_DIR/scaffold/Makefile" "$project_dir/Makefile"

  if [ -f "$project_dir/docker-compose.yml" ]; then
    mv "$project_dir/docker-compose.yml" "$project_dir/docker-compose.yml.orig"
    warn "Project already had a docker-compose.yml -- preserved as docker-compose.yml.orig"
  fi
  cp "$SOURCE_DIR/docker-compose.yml" "$project_dir/docker-compose.yml"

  if [ -f "$project_dir/.gitignore" ]; then
    printf '\n# Added by create-latex-app\n' >> "$project_dir/.gitignore"
    grep -v -e '^/site/$' -e 'GitHub Pages' "$SOURCE_DIR/.gitignore" >> "$project_dir/.gitignore"
  else
    grep -v -e '^/site/$' -e 'GitHub Pages' "$SOURCE_DIR/.gitignore" > "$project_dir/.gitignore"
  fi

  if [ ! -f "$project_dir/README.md" ]; then
    sed -e "s/__PROJECT_NAME__/$PROJECT_NAME/g" -e "s/__MAIN__/$MAIN_FILE/g" \
      "$SOURCE_DIR/scaffold/README.md" > "$project_dir/README.md"
  fi
}

apply_makefile_config() {
  local project_dir="$1"
  [ -n "$ENGINE_OVERRIDE" ] && ENGINE="$ENGINE_OVERRIDE"
  [ -n "$SHELL_ESCAPE_OVERRIDE" ] && SHELL_ESCAPE_VAL="$SHELL_ESCAPE_OVERRIDE"
  local mk="$project_dir/Makefile"
  sed -i.bak \
    -e "s/^MAIN := .*/MAIN := $MAIN_FILE/" \
    -e "s/^ENGINE := .*/ENGINE := $ENGINE/" \
    -e "s/^SHELL_ESCAPE := .*/SHELL_ESCAPE := $SHELL_ESCAPE_VAL/" \
    "$mk"
  rm -f "$mk.bak"
}

finalize_git() {
  local project_dir="$1"
  if ( cd "$project_dir" && git init -q && git add -A && git commit -q -m "Initial commit from create-latex-app" ) >/dev/null 2>&1; then
    ok "Initialized a fresh git repository with an initial commit"
  else
    warn "Could not create an initial git commit (git user.name/user.email may not be configured) -- 'git init' was skipped or left uncommitted."
  fi
}

maybe_build() {
  local project_dir="$1"
  [ "$NO_BUILD" = "true" ] && return
  local ans="y"
  if ! read -r -p "Build it now with Docker? Pulls the texlive image on first run (a few GB). [Y/n] " ans; then
    ans="n"
  fi
  case "$ans" in
    [nN]*) return ;;
  esac
  step "Pulling the texlive/texlive image (first time only, can take a few minutes)..."
  ( cd "$project_dir" && docker compose pull ) || warn "Could not pull the Docker image -- check your network and try 'make pull' later."
  step "Compiling $MAIN_FILE..."
  if ( cd "$project_dir" && make build ); then
    local pdf_name="${MAIN_FILE%.tex}.pdf"
    ok "Built $project_dir/$pdf_name"
  else
    warn "Build failed -- check the .log file in $project_dir, or run 'make shell' there to debug interactively."
  fi
}

print_next_steps() {
  echo
  echo "${BOLD}Next steps:${RESET}"
  echo "  cd $PROJECT_NAME"
  echo "  make build     # compile $MAIN_FILE"
  echo "  make watch     # recompile on every save"
  echo "  make help      # see all commands"
  echo
  echo "Happy writing!"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "${BOLD}create-latex-app${RESET} -- scaffold a Dockerized LaTeX project"
echo

prompt_project_name
validate_project_name
prompt_mode
resolve_source
verify_source

case "$MODE" in
  template) prompt_template ;;
  zip) prompt_zip_path ;;
  git) prompt_git_url ;;
  *) fail "Internal error: unknown mode '$MODE'" ;;
esac

mkdir "$PROJECT_NAME" || fail "Could not create directory '$PROJECT_NAME'"
PROJECT_DIR="$(cd "$PROJECT_NAME" && pwd)"
PROJECT_DIR_CREATED="$PROJECT_DIR"

case "$MODE" in
  template) populate_template "$PROJECT_DIR" ;;
  zip) populate_zip "$PROJECT_DIR" ;;
  git) populate_git "$PROJECT_DIR" ;;
esac

scaffold_common "$PROJECT_DIR"
apply_makefile_config "$PROJECT_DIR"
finalize_git "$PROJECT_DIR"

PROJECT_DIR_CREATED=""
echo
ok "Created ${BOLD}$PROJECT_NAME${RESET}/"
echo

maybe_build "$PROJECT_DIR"
print_next_steps
