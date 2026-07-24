#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "${script_directory}/.." && pwd)"
default_ttl="2h"
failed_templates=()

templates=(
  "ai-dev"
  "aws-ai-dev"
  "gcp-ai-dev"
)

for template_name in "${templates[@]}"; do
  template_directory="${repository_root}/registry/coder-labs/templates/${template_name}"

  if ! coder templates push \
    "${template_name}" \
    --directory "${template_directory}" \
    --message "Update ${template_name}" \
    --yes; then
    failed_templates+=("${template_name}")
    continue
  fi

  if ! coder templates edit "${template_name}" --default-ttl "${default_ttl}"; then
    failed_templates+=("${template_name}")
  fi
done

if ((${#failed_templates[@]} > 0)); then
  printf 'Failed templates: %s\n' "${failed_templates[*]}" >&2
  exit 1
fi
