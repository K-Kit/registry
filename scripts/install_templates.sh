#!/usr/bin/env bash
set -euo pipefail

# Installs (pushes) Coder Registry templates to a Coder deployment using the
# `coder` CLI (`coder templates push`). Templates live under
# registry/<namespace>/templates/<name>/ and each has a main.tf.
#
# Run from the repository root. Select templates with --all, --namespace, or by
# passing "<namespace>/<name>" (or a bare "<name>" when it is unambiguous).
#
# Examples:
#   ./scripts/install_templates.sh --all
#   ./scripts/install_templates.sh --namespace coder
#   ./scripts/install_templates.sh coder/docker coder/kubernetes
#   ./scripts/install_templates.sh --all --dry-run
#   ./scripts/install_templates.sh coder/docker -- --variable namespace=coder

usage() {
  cat << 'EOF'
Usage: ./scripts/install_templates.sh [options] [<namespace>/<name> ...]

Push one or more Coder Registry templates to the Coder deployment you are
currently logged in to (via the `coder` CLI).

Selection (choose one):
  -a, --all                 Install every template in the registry.
  -n, --namespace <ns>      Install every template under registry/<ns>/templates.
  <namespace>/<name> ...    Install specific templates. A bare <name> is
                            accepted when it is unique across namespaces.

Options:
      --plain-names         Name the Coder template after its directory only
                            (default is "<namespace>-<name>" to avoid clashes).
      --dry-run             Print the `coder templates push` commands without
                            running them (does not require the coder CLI).
  -h, --help                Show this help.
      --                    Pass all following arguments straight to
                            `coder templates push` (e.g. --variable k=v).
EOF
}

DRY_RUN=false
ALL=false
PLAIN_NAMES=false
NAMESPACE=""
declare -a SELECTORS=()
declare -a CODER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -a | --all)
      ALL=true
      shift
      ;;
    -n | --namespace)
      NAMESPACE="${2:?--namespace requires a value}"
      shift 2
      ;;
    --plain-names)
      PLAIN_NAMES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --)
      shift
      CODER_ARGS+=("$@")
      break
      ;;
    -*)
      echo "Error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
    *)
      SELECTORS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -d registry ]]; then
  echo "Error: run this script from the repository root (registry/ not found)." >&2
  exit 1
fi

# Discover every template directory (the parent of each templates/*/main.tf).
declare -a ALL_TEMPLATES=()
while IFS= read -r dir; do
  ALL_TEMPLATES+=("$dir")
done < <(find registry -type f -path '*/templates/*/main.tf' | sed 's|/main.tf$||' | sort -u)

if [[ ${#ALL_TEMPLATES[@]} -eq 0 ]]; then
  echo "Error: no templates found under registry/*/templates/*." >&2
  exit 1
fi

# Resolve a user selector ("<ns>/<name>", a bare "<name>", or a path) to a
# template directory, or fail with a helpful message.
resolve_selector() {
  local sel="$1"
  sel="${sel%/}"

  # Already a concrete template directory.
  if [[ -f "$sel/main.tf" && "$sel" == registry/*/templates/* ]]; then
    echo "$sel"
    return 0
  fi

  # "<namespace>/<name>" form.
  if [[ "$sel" == */* ]]; then
    local ns="${sel%%/*}" name="${sel##*/}"
    local dir="registry/${ns}/templates/${name}"
    if [[ -f "$dir/main.tf" ]]; then
      echo "$dir"
      return 0
    fi
    echo "Error: no template found for '$sel' (expected $dir/main.tf)." >&2
    return 1
  fi

  # Bare "<name>": match on directory basename across namespaces.
  local match matches=()
  for match in "${ALL_TEMPLATES[@]}"; do
    if [[ "${match##*/}" == "$sel" ]]; then
      matches+=("$match")
    fi
  done
  case ${#matches[@]} in
    1)
      echo "${matches[0]}"
      return 0
      ;;
    0)
      echo "Error: no template named '$sel' found." >&2
      return 1
      ;;
    *)
      echo "Error: '$sel' is ambiguous; matches: ${matches[*]}" >&2
      echo "       Qualify it as <namespace>/<name>." >&2
      return 1
      ;;
  esac
}

# Build the list of template directories to install.
declare -a SELECTED=()
if [[ "$ALL" == true ]]; then
  SELECTED=("${ALL_TEMPLATES[@]}")
elif [[ -n "$NAMESPACE" ]]; then
  for dir in "${ALL_TEMPLATES[@]}"; do
    if [[ "$dir" == "registry/${NAMESPACE}/templates/"* ]]; then
      SELECTED+=("$dir")
    fi
  done
  if [[ ${#SELECTED[@]} -eq 0 ]]; then
    echo "Error: no templates found under registry/${NAMESPACE}/templates/." >&2
    exit 1
  fi
elif [[ ${#SELECTORS[@]} -gt 0 ]]; then
  for sel in "${SELECTORS[@]}"; do
    dir="$(resolve_selector "$sel")"
    SELECTED+=("$dir")
  done
else
  echo "Error: nothing selected. Pass --all, --namespace <ns>, or template names." >&2
  usage >&2
  exit 1
fi

# Derive the Coder template name for a given directory.
coder_template_name() {
  local dir="$1"
  local name="${dir##*/}"
  if [[ "$PLAIN_NAMES" == true ]]; then
    echo "$name"
    return
  fi
  local rest="${dir#registry/}"
  local ns="${rest%%/*}"
  echo "${ns}-${name}"
}

# Preconditions that only matter when we actually push.
if [[ "$DRY_RUN" == false ]]; then
  if ! command -v coder > /dev/null 2>&1; then
    echo "Error: the 'coder' CLI is not installed or not on PATH." >&2
    echo "       Install it from https://coder.com/docs/install, then run 'coder login <url>'." >&2
    exit 1
  fi
  if ! coder whoami > /dev/null 2>&1; then
    echo "Error: not logged in to a Coder deployment. Run 'coder login <url>' first." >&2
    exit 1
  fi
fi

echo "==> Installing ${#SELECTED[@]} template(s)"

declare -a FAILED=()
for dir in "${SELECTED[@]}"; do
  name="$(coder_template_name "$dir")"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] coder templates push '$name' --directory '$dir' --yes ${CODER_ARGS[*]}"
    continue
  fi

  echo "==> Pushing '$name' from $dir"
  if coder templates push "$name" --directory "$dir" --yes "${CODER_ARGS[@]}"; then
    echo "    OK: $name"
  else
    echo "    FAILED: $name" >&2
    FAILED+=("$name")
  fi
done

if [[ "$DRY_RUN" == true ]]; then
  echo "==> Dry run complete (${#SELECTED[@]} template(s) would be pushed)."
  exit 0
fi

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "==> Done with errors. Failed (${#FAILED[@]}): ${FAILED[*]}" >&2
  exit 1
fi
echo "==> All ${#SELECTED[@]} template(s) installed successfully."
