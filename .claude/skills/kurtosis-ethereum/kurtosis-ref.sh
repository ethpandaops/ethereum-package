#!/usr/bin/env bash
# Unified reference tool for ethereum-package configuration.
# Only fetches the source file(s) needed for the requested section.
#
# Usage:
#   bash .claude/skills/kurtosis/kurtosis-ref.sh <section>
#
# Sections:
#   clients       Supported EL/CL/VC client types
#   participants  Participant fields with defaults
#   network       network_params fields with defaults
#   forks         Fork epoch fields and defaults
#   mev           MEV types and params
#   services      Additional services list
#   sections      Config subcategory and root-level params
#   search <term> Search the README for a field/concept
#   example <name> Fetch a CI test config (e.g. remote-signer, minimal, mix)
#   examples      List available CI test configs
#   all           Dump all sections
set -euo pipefail

SECTION="${1:-all}"
SEARCH_TERM="${2:-}"

BASE="https://raw.githubusercontent.com/ethpandaops/ethereum-package/main/src/package_io"
README_URL="https://raw.githubusercontent.com/ethpandaops/ethereum-package/main/README.md"
TESTS_URL="https://raw.githubusercontent.com/ethpandaops/ethereum-package/main/.github/tests"
TESTS_LIST_URL="https://api.github.com/repos/ethpandaops/ethereum-package/contents/.github/tests"

# Lazy loaders — each file fetched at most once per invocation
fetch_constants()    { [[ -z "${constants:-}" ]]    && constants=$(curl -sfL "$BASE/constants.star"); }
fetch_input_parser() { [[ -z "${input_parser:-}" ]] && input_parser=$(curl -sfL "$BASE/input_parser.star"); }
fetch_sanity_check() { [[ -z "${sanity_check:-}" ]] && sanity_check=$(curl -sfL "$BASE/sanity_check.star"); }

join_csv() { tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'; }

show_clients() {
  fetch_constants
  echo "## Supported Client Types"
  echo ""
  echo -n "EL: "; echo "$constants" | sed -n '/^EL_TYPE = struct(/,/^)/p' | grep '^ ' | sed 's/.*"\(.*\)".*/\1/' | join_csv; echo
  echo -n "CL: "; echo "$constants" | sed -n '/^CL_TYPE = struct(/,/^)/p' | grep '^ ' | sed 's/.*"\(.*\)".*/\1/' | join_csv; echo
  echo -n "VC: "; echo "$constants" | sed -n '/^VC_TYPE = struct(/,/^)/p' | grep '^ ' | sed 's/.*"\(.*\)".*/\1/' | join_csv; echo
}

show_participants() {
  fetch_input_parser
  echo "## Participant Fields (defaults)"
  echo ""
  echo "$input_parser" | sed -n '/^def default_participant/,/^def /p' | grep '^ *"[a-z]' | grep -v '^\s*"prometheus_config' | grep -v '^\s*"scrape_interval' | grep -v '^\s*"labels' | sed 's/^ *"\(.*\)": \(.*\),$/\1: \2/' | grep -v '^[[:space:]]*$'
  echo "prometheus_config: {scrape_interval: \"15s\", labels: None}"
}

show_network() {
  fetch_input_parser
  echo "## network_params Fields (defaults)"
  echo ""
  echo "$input_parser" | sed -n '/^def default_network_params/,/^def /p' | grep '^ *"' | sed 's/^ *"\(.*\)": \(.*\),$/\1: \2/' | sed 's/constants\.DEFAULT_MNEMONIC/"<default-mnemonic>"/' | sed 's/constants\.FAR_FUTURE_EPOCH/FAR_FUTURE/'
}

show_forks() {
  fetch_input_parser
  echo "## Fork Epoch Defaults"
  echo ""
  echo "$input_parser" | sed -n '/^def default_network_params/,/^def /p' | grep '_fork_epoch' | sed 's/^ *"\(.*\)": \(.*\),$/\1: \2/' | sed 's/constants.FAR_FUTURE_EPOCH/FAR_FUTURE/'
}

show_mev() {
  fetch_constants
  echo "## MEV Types"
  echo ""
  echo "$constants" | grep '_MEV_TYPE = ' | sed 's/.*= "\(.*\)"/\1/' | join_csv; echo
  echo ""
  echo "## MEV Config"
  echo "Set mev_type at root level. Optional mev_params for custom images."
  echo "Participant-level: el_builder_type, cl_builder_type for builder roles."
}

show_services() {
  fetch_sanity_check
  echo "## Additional Services"
  echo ""
  echo "$sanity_check" | sed -n '/^ADDITIONAL_SERVICES_PARAMS = \[/,/^\]/p' | grep '"' | sed 's/.*"\(.*\)".*/\1/' | join_csv; echo
}

show_sections() {
  fetch_sanity_check
  echo "## Config Subcategory Params"
  echo ""
  echo "$sanity_check" | sed -n '/^SUBCATEGORY_PARAMS = {/,/^}/p' | grep '^ *"[a-z_]*": \[' | sed 's/^ *"\([a-z_]*\)".*/\1/' | sort -u | join_csv; echo
  echo ""
  echo "## Root-Level Params"
  echo ""
  echo "$sanity_check" | sed -n '/^ADDITIONAL_CATEGORY_PARAMS = {/,/^}/p' | grep '^ *"' | sed 's/^ *"\([a-z_]*\)".*/\1/' | join_csv; echo
}

do_search() {
  local term="$1"
  local readme
  readme=$(curl -sfL "$README_URL")
  echo "## Matches for '${term}' in ethereum-package README"
  echo ""
  echo "$readme" | grep -n -i -B3 -A2 "$term" | head -80
  echo ""
  echo "(Up to 80 lines shown. Refine search term if needed.)"
}

do_example() {
  local name="$1"
  # Try with .yaml extension first, then .yml
  local content
  content=$(curl -sfL "$TESTS_URL/${name}.yaml" 2>/dev/null) || \
  content=$(curl -sfL "$TESTS_URL/${name}.yml" 2>/dev/null) || \
  content=$(curl -sfL "$TESTS_URL/${name}" 2>/dev/null) || {
    echo "No test config found for '${name}'."
    echo "Use 'kurtosis-ref.sh examples' to list available configs."
    return 1
  }
  echo "## CI test config: ${name}"
  echo ""
  echo "$content"
}

do_examples_list() {
  local listing
  listing=$(curl -sfL "$TESTS_LIST_URL") || {
    echo "Failed to fetch test config listing."
    return 1
  }
  echo "## Available CI test configs"
  echo ""
  echo "$listing" | grep '"name"' | sed 's/.*"name": "\(.*\)".*/\1/' | sed 's/\.yaml$//' | sed 's/\.yml$//' | sort
}

case "$SECTION" in
  clients)      show_clients ;;
  participants)  show_participants ;;
  network|network_params) show_network ;;
  forks)        show_forks ;;
  mev)          show_mev ;;
  services)     show_services ;;
  sections)     show_sections ;;
  search)
    if [[ -z "$SEARCH_TERM" ]]; then
      echo "Usage: kurtosis-ref.sh search <term>"
      exit 1
    fi
    do_search "$SEARCH_TERM"
    ;;
  example)
    if [[ -z "$SEARCH_TERM" ]]; then
      echo "Usage: kurtosis-ref.sh example <name>"
      exit 1
    fi
    do_example "$SEARCH_TERM"
    ;;
  examples) do_examples_list ;;
  all)
    fetch_constants; fetch_input_parser; fetch_sanity_check
    show_clients; echo ""
    show_mev; echo ""
    show_services; echo ""
    show_forks; echo ""
    show_network; echo ""
    show_participants; echo ""
    show_sections
    ;;
  *)
    echo "Unknown section: $SECTION"
    echo "Available: clients, participants, network, forks, mev, services, sections, search <term>, example <name>, examples, all"
    exit 1
    ;;
esac
