#!/usr/bin/env zsh

function kgp() {
  if [ -z "$1" ]; then
    kubectl get po
  else
    kubectl get po | fzf --filter="$1"
  fi
}

function kgnsonly() {
  kubectl get namespaces | awk 'NR!=1 {print $1}'
}

function kgnonly() {
  local flag=""
  local filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -a | --all)
      flag="all"
      shift
      ;;
    *)
      filter="$1"
      shift
      ;;
    esac
  done

  if [ "$flag" == "all" ]; then
    kgnonly.allCluster $filter | sort -u
    return
  fi

  if [ -z "$filter" ]; then
    kubectl get nodes | awk 'NR!=1 {print $1}'
    return
  fi
  kubectl get nodes | grep "$filter" | awk '{print $1}'
}

function kgnonly.allCluster() {
  local originalContext=$(kubectl config current-context)
  for cluster in $(kubectl config get-contexts -o=name); do
    kubectl config use-context $cluster >/dev/null 1>&1
    kgnonly $1
  done
  kubectl config use-context $originalContext >/dev/null 1>&1
}

function __kli_usage() {
  echo "Usage: kli [-A] [-n <namespace>] tag"
}

function kli() {
  local kubectl_args=""
  local tag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -A)
      kubectl_args="$kubectl_args -A"
      shift
      ;;
    -n | --namespace)
      kubectl_args="$kubectl_args $1 $2"
      shift 2
      ;;
    -h | --help)
      __kli_usage
      return
      ;;
    *)
      tag="$tag $1"
      shift
      ;;
    esac
  done
  if [ -n "$tag" ]; then
    kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image | {
      head -1
      grep $tag
    } | column -t
    return
  fi
  kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image
}
# function kc() {
#     kubectl config use-context $1
# }
function __refresh_kubecontexts() {
  complete -W "$(kubectl config get-contexts -o=name)" kc
}

function __kgnsonly_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kgnsonly)" -- $cur))
}

function __kgnonly_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kgnonly)" -- $cur))
}

function __kc_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kubectl config get-contexts -o=name)" -- $cur))
}

function k.node.debug() {
  if [ -z "$1" ]; then
    echo -e "${WARNING}${RED} Node name not found: ${YELLOW}$1${NC}"
    return
  fi
  echo -e "${YELLOW}===========================================${NC}"
  echo -e "${ARROW}${CYAN} $1 ${YELLOW}: [${GREEN}${@:2}${YELLOW}] : ${SEA}$(TZ="America/Chicago" date)${NC}"
  echo -e "${YELLOW}===========================================${NC}"
  kubectl debug node/$1 -qit --image=mcr.microsoft.com/dotnet/runtime-deps:6.0 --target $1 -- chroot /host bash
}

function k.togglePromptInfo() {
  # create export if not exists
  if [ -z "$SHOW_K8S_PROMPT_INFO" ]; then
    export SHOW_K8S_PROMPT_INFO="false"
    return
  elif [ "$SHOW_K8S_PROMPT_INFO" == "true" ]; then
    export SHOW_K8S_PROMPT_INFO="false"
    return
  elif [ "$SHOW_K8S_PROMPT_INFO" == "false" ]; then
    export SHOW_K8S_PROMPT_INFO="true"
    return
  fi
}

function select_pod() {
  command -v fzf >/dev/null || {
    echo "fzf is not installed."
    return 1
  }
  command -v jq >/dev/null || {
    echo "jq is not installed."
    return 1
  }

  local search_term="$1"
  local prioritize_active="$2"
  local all_pods=""
  local matching_pods=""
  local selected_pod=""

  if [ "$prioritize_active" = "true" ]; then
    all_pods=$(kubectl get pods --no-headers | awk '{print $1, $3}' | sort -k2,2 -r)
  else
    all_pods=$(kubectl get pods --no-headers)
  fi

  if [ -z "$search_term" ]; then
    selected_pod=$(echo "$all_pods" | fzf --height 40% --reverse | awk '{print $1}')
    echo "$selected_pod"
    return 0
  fi

  matching_pods=$(echo "$all_pods" | grep -i "$search_term")
  local match_count
  match_count=$(echo "$matching_pods" | grep -v "^$" | wc -l)

  if [ "$match_count" -eq 1 ]; then
    echo "$matching_pods" | awk '{print $1}' | tr -d '\n'
    return 0
  elif [ "$match_count" -gt 1 ]; then
    echo "Found $match_count pods matching '$search_term'. Please select one:" >&2
    selected_pod=$(echo "$matching_pods" | fzf --height 40% --reverse --query="$search_term" | awk '{print $1}')
    echo "$selected_pod"
    return 0
  fi

  echo "No exact matches for '$search_term'. Trying fuzzy search:" >&2
  local fuzzy_matches
  fuzzy_matches=$(echo "$all_pods" | fzf --filter="$search_term" | wc -l)

  if [ "$fuzzy_matches" -eq 1 ]; then
    local fuzzy_pod
    fuzzy_pod=$(echo "$all_pods" | fzf --filter="$search_term" | awk '{print $1}')
    echo "Found single fuzzy match: $fuzzy_pod" >&2
    echo "$fuzzy_pod"
    return 0
  fi

  echo "Select from all pods:" >&2
  selected_pod=$(echo "$all_pods" | fzf --height 40% --reverse --query="$search_term" | awk '{print $1}')
  echo "$selected_pod"
}

function kpl() {
  local pod_name
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Getting logs for pod: $pod_name"
    kubectl logs "$pod_name"
  fi
}

function kpd() {
  local pod_name
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Describing pod: $pod_name"
    kubectl describe pod "$pod_name"
  fi
}

function kpx() {
  local pod_name
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Exec into pod: $pod_name"
    local kcommand="/bin/sh"
    if [ -n "$2" ]; then
      kcommand="$2"
    fi
    kubectl exec -it "$pod_name" -- "$kcommand"
  fi
}

function kpexec() {
  kpx "$@"
}

function kpg() {
  local pod_name
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "$pod_name"
  fi
}

function kpdel() {
  command -v fzf >/dev/null || {
    echo "fzf is not installed."
    return 1
  }

  local search_term="$1"
  local all_pods
  local selected_pods

  all_pods=$(kubectl get pods --no-headers | awk '{print $1, $3}' | sort -k2,2 -r)

  if [ -z "$all_pods" ]; then
    echo "No pods found in current namespace."
    return 1
  fi

  if [ -z "$search_term" ]; then
    selected_pods=$(echo "$all_pods" | fzf --multi --height 40% --reverse \
      --header="Select pods to delete (Tab to select, Enter to confirm)" | awk '{print $1}')
  else
    local matching_pods
    matching_pods=$(echo "$all_pods" | grep -i "$search_term")

    if [ -z "$matching_pods" ]; then
      matching_pods=$(echo "$all_pods" | fzf --filter="$search_term")
    fi

    if [ -z "$matching_pods" ]; then
      echo "No pods matching '$search_term' found."
      return 1
    fi

    local match_count
    match_count=$(echo "$matching_pods" | grep -v "^$" | wc -l)

    if [ "$match_count" -eq 1 ]; then
      selected_pods=$(echo "$matching_pods" | awk '{print $1}')
    else
      selected_pods=$(echo "$matching_pods" | fzf --multi --height 40% --reverse \
        --query="$search_term" \
        --header="Select pods to delete (Tab to select, Enter to confirm)" | awk '{print $1}')
    fi
  fi

  if [ -z "$selected_pods" ]; then
    echo "No pods selected. Aborting."
    return 0
  fi

  local pod_count
  pod_count=$(echo "$selected_pods" | grep -v "^$" | wc -l)

  echo ""
  echo -e "\033[1;33mThe following $pod_count pod(s) will be deleted:\033[0m"
  echo ""
  echo "$selected_pods" | while read -r pod; do
    echo -e "  \033[0;31m-\033[0m $pod"
  done
  echo ""

  echo -n -e "\033[1;33mAre you sure you want to delete these pods? [y/N]: \033[0m"
  read -r confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "$selected_pods" | while read -r pod; do
      if [ -n "$pod" ]; then
        echo -e "\033[0;36mDeleting pod:\033[0m $pod"
        kubectl delete pod "$pod"
      fi
    done
    echo ""
    echo -e "\033[0;32mDone.\033[0m"
  else
    echo "Aborted."
    return 0
  fi
}

function kgetall {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local MAGENTA='\033[0;35m'
  local CYAN='\033[0;36m'
  local WHITE='\033[1;37m'
  local NC='\033[0m'
  local BOLD='\033[1m'
  local DIM='\033[2m'

  local namespace=""
  local grep_pattern=""
  local use_fuzzy=false
  local fuzzy_pattern=""

  show_usage() {
    echo -e "${BOLD}${WHITE}Usage: kgetall [OPTIONS]${NC}"
    echo -e "${WHITE}  -n, --namespace <namespace>    Specify namespace${NC}"
    echo -e "${WHITE}  -g, --grep <pattern>           Grep filter on resource items${NC}"
    echo -e "${WHITE}  -f, --fuzzy [pattern]          Use fzf for fuzzy search (interactive if no pattern)${NC}"
    echo -e "${WHITE}  -h, --help                     Show this help${NC}"
    echo
    echo -e "${WHITE}Examples:${NC}"
    echo -e "${DIM}  kgetall -n kube-system${NC}"
    echo -e "${DIM}  kgetall -g \"nginx\"${NC}"
    echo -e "${DIM}  kgetall -f \"pod\"${NC}"
    echo -e "${DIM}  kgetall -n default -g \"app=web\"${NC}"
    echo -e "${DIM}  kgetall --fuzzy          # Interactive fuzzy search${NC}"
  }

  while [[ $# -gt 0 ]]; do
    case $1 in
    -n | --namespace)
      namespace="$2"
      shift 2
      ;;
    -g | --grep)
      grep_pattern="$2"
      shift 2
      ;;
    -f | --fuzzy)
      use_fuzzy=true
      if [[ $# -gt 1 ]] && [[ ! "$2" =~ ^- ]]; then
        fuzzy_pattern="$2"
        shift 2
      else
        shift
      fi
      ;;
    -h | --help)
      show_usage
      return 0
      ;;
    *)
      if [[ -z "$namespace" ]] && [[ ! "$1" =~ ^- ]]; then
        namespace="$1"
        shift
      else
        echo -e "${RED}Unknown option: $1${NC}" >&2
        show_usage
        return 1
      fi
      ;;
    esac
  done

  if $use_fuzzy && ! command -v fzf &>/dev/null; then
    echo -e "${RED}Error: fzf is not installed. Please install fzf for fuzzy search functionality.${NC}" >&2
    return 1
  fi

  filter_output() {
    local output="$1"
    local resource_name="$2"

    if [[ -z "$output" ]] || [[ "$(echo "$output" | wc -l)" -le 1 ]]; then
      return 1
    fi

    local filtered_output=""
    local header_line=""
    local has_matches=false

    header_line=$(echo "$output" | head -n1)

    if [[ -n "$grep_pattern" ]]; then
      local data_lines=$(echo "$output" | tail -n +2 | grep -i "$grep_pattern")
      if [[ -n "$data_lines" ]]; then
        filtered_output=$(echo -e "$header_line\n$data_lines")
        has_matches=true
      fi
    elif $use_fuzzy; then
      if [[ -n "$fuzzy_pattern" ]]; then
        local data_lines=$(echo "$output" | tail -n +2 | fzf -f "$fuzzy_pattern")
        if [[ -n "$data_lines" ]]; then
          filtered_output=$(echo -e "$header_line\n$data_lines")
          has_matches=true
        fi
      else
        local temp_file=$(mktemp)
        echo "$output" | tail -n +2 >"$temp_file"
        if [[ -s "$temp_file" ]]; then
          echo -e "${DIM}${YELLOW}-> Press Enter to fuzzy search ${resource_name} (Ctrl+C to skip)${NC}" >&2
          local selected_lines=$(cat "$temp_file" | fzf --multi --header="Select ${resource_name} items (Tab to select multiple, Enter to confirm)")
          if [[ -n "$selected_lines" ]]; then
            filtered_output=$(echo -e "$header_line\n$selected_lines")
            has_matches=true
          fi
        fi
        rm -f "$temp_file"
      fi
    else
      filtered_output="$output"
      has_matches=true
    fi

    if $has_matches; then
      echo "$filtered_output"
      return 0
    fi

    return 1
  }

  echo -e "${BOLD}${CYAN}========================================${NC}"
  local header_text="Kubectl Get All Resources"
  if [[ -n "$namespace" ]]; then
    header_text+=" (Namespace: ${YELLOW}$namespace${WHITE})"
  else
    header_text+=" (All Namespaces)"
  fi

  if [[ -n "$grep_pattern" ]]; then
    header_text+=" [Grep: ${GREEN}$grep_pattern${WHITE}]"
  elif $use_fuzzy; then
    if [[ -n "$fuzzy_pattern" ]]; then
      header_text+=" [Fuzzy: ${GREEN}$fuzzy_pattern${WHITE}]"
    else
      header_text+=" [Interactive Fuzzy Search]"
    fi
  fi

  echo -e "${BOLD}${WHITE}$header_text${NC}"
  echo -e "${BOLD}${CYAN}========================================${NC}"
  echo

  local resource_count=0
  local resources_with_items=0
  local filtered_resources=0

  for i in $(kubectl api-resources --verbs=list --namespaced -o name | grep -v "events.events.k8s.io" | grep -v "events" | sort | uniq); do
    resource_count=$((resource_count + 1))

    local output=""
    if [[ -n "$namespace" ]]; then
      output=$(kubectl -n "$namespace" get --ignore-not-found "$i" 2>/dev/null)
    else
      output=$(kubectl get --ignore-not-found "$i" 2>/dev/null)
    fi

    if [[ -n "$output" ]] && [[ "$(echo "$output" | wc -l)" -gt 1 ]]; then
      resources_with_items=$((resources_with_items + 1))

      local filtered_output=""
      if filtered_output=$(filter_output "$output" "$i"); then
        filtered_resources=$((filtered_resources + 1))

        echo -e "${BOLD}${MAGENTA}+ Resource: ${GREEN}${i}${NC}"
        echo -e "${DIM}${CYAN}|${NC}"

        echo "$filtered_output" | while IFS= read -r line; do
          if [[ "$line" =~ ^NAME[[:space:]] ]] || [[ "$line" =~ ^NAMESPACE[[:space:]] ]]; then
            echo -e "${DIM}${CYAN}|${NC} ${BOLD}${BLUE}${line}${NC}"
          else
            echo -e "${DIM}${CYAN}|${NC} ${line}"
          fi
        done

        echo -e "${DIM}${CYAN}+-${NC}"
        echo
      fi
    fi
  done

  echo -e "${BOLD}${CYAN}========================================${NC}"
  echo -e "${BOLD}${WHITE}Summary:${NC}"
  echo -e "${WHITE}  Total resource types checked: ${GREEN}${resource_count}${NC}"
  echo -e "${WHITE}  Resource types with items: ${GREEN}${resources_with_items}${NC}"

  if [[ -n "$grep_pattern" ]] || $use_fuzzy; then
    echo -e "${WHITE}  Resource types after filtering: ${GREEN}${filtered_resources}${NC}"
  fi

  if [[ -n "$namespace" ]]; then
    echo -e "${WHITE}  Scope: ${YELLOW}Namespace '$namespace'${NC}"
  else
    echo -e "${WHITE}  Scope: ${YELLOW}All namespaces${NC}"
  fi

  if [[ -n "$grep_pattern" ]]; then
    echo -e "${WHITE}  Filter: ${GREEN}grep '$grep_pattern'${NC}"
  elif $use_fuzzy; then
    if [[ -n "$fuzzy_pattern" ]]; then
      echo -e "${WHITE}  Filter: ${GREEN}fuzzy '$fuzzy_pattern'${NC}"
    else
      echo -e "${WHITE}  Filter: ${GREEN}interactive fuzzy search${NC}"
    fi
  fi

  echo -e "${BOLD}${CYAN}========================================${NC}"
}

function kpatchall {
  local pods
  pods=$(kubectl get pods -o json | jq -r '.items[] | select(.status.phase == "Pending" and ((.spec.tolerations == null) or (.spec.tolerations | length == 0) or (.spec.tolerations | map(select(.key == "raft")) | length == 0))) | .metadata.name')

  for pod in $pods; do
    kubectl patch pod "$pod" --patch '{"spec": {"tolerations": [{"key": "core", "operator": "Exists", "effect": "NoSchedule"}]}}'
  done
}

function watchpo() {
  watch -n 2 "kubectl get po | fzf --filter='$1' | head -20"
}

function __k_import_context_complete() {
  local -a opts
  opts=(
    '--destination[Destination kubeconfig file]:destination kubeconfig:_files'
    '--import[Kubeconfig file to import]:source kubeconfig:_files'
    '--context[Source context inside the import kubeconfig]:source context:'
    '--new-name[Rename the imported context, cluster, and user to this value]:new name:'
    '--ssh-session[SSH session used to fetch a remote kubeconfig]:ssh session:_ssh'
    '--remote-server[Override the imported cluster server URL]:server URL:'
    '--help[Display usage information]'
  )
  _arguments $opts
}

function __k.importContext_resolve_source_context() {
  emulate -L zsh

  local kubeconfig_path="$1"
  local requested_context="$2"
  local current_context=""
  local -a contexts

  contexts=("${(@f)$(kubectl config --kubeconfig="$kubeconfig_path" get-contexts -o=name 2>/dev/null)}")

  if (( ${#contexts[@]} == 0 )); then
    printf "${RED}Error:${NC} no contexts were found in %s\n" "$kubeconfig_path" >&2
    return 1
  fi

  if [[ -n "$requested_context" ]]; then
    if (( ${contexts[(Ie)$requested_context]} )); then
      print -r -- "$requested_context"
      return 0
    fi

    printf "${RED}Error:${NC} context %s was not found in %s\n" "'$requested_context'" "$kubeconfig_path" >&2
    return 1
  fi

  current_context="$(kubectl config --kubeconfig="$kubeconfig_path" current-context 2>/dev/null)"
  if [[ -n "$current_context" ]]; then
    print -r -- "$current_context"
    return 0
  fi

  if (( ${#contexts[@]} == 1 )); then
    print -r -- "$contexts[1]"
    return 0
  fi

  printf "${RED}Error:${NC} multiple contexts were found and the kubeconfig has no current-context\n" >&2
  printf "Pass ${BOLD}--context${NC} to choose one of:\n" >&2
  printf "  %s\n" "${contexts[@]}" >&2
  return 1
}

function __k.importContext_resolve_host_to_ip() {
  emulate -L zsh

  local host="$1"
  local resolved_ip=""

  if [[ -z "$host" ]]; then
    return 1
  fi

  host="${host#\[}"
  host="${host%\]}"

  if [[ "$host" == <->.<->.<->.<-> || "$host" == *:* ]]; then
    print -r -- "$host"
    return 0
  fi

  if command -v getent >/dev/null 2>&1; then
    resolved_ip="$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR == 1 { print $1; exit }')"
    if [[ -n "$resolved_ip" ]]; then
      print -r -- "$resolved_ip"
      return 0
    fi
  fi

  if command -v dscacheutil >/dev/null 2>&1; then
    resolved_ip="$(dscacheutil -q host -a name "$host" 2>/dev/null | awk '/^ip_address: / { print $2; exit }')"
    if [[ -n "$resolved_ip" ]]; then
      print -r -- "$resolved_ip"
      return 0
    fi
  fi

  if command -v dig >/dev/null 2>&1; then
    resolved_ip="$(dig +short A "$host" 2>/dev/null | awk 'NF { print; exit }')"
    if [[ -n "$resolved_ip" ]]; then
      print -r -- "$resolved_ip"
      return 0
    fi
  fi

  if command -v host >/dev/null 2>&1; then
    resolved_ip="$(host "$host" 2>/dev/null | awk '/ has address / { print $NF; exit }')"
    if [[ -n "$resolved_ip" ]]; then
      print -r -- "$resolved_ip"
      return 0
    fi
  fi

  return 1
}

function __k.importContext_resolve_ssh_host() {
  emulate -L zsh

  local ssh_target="$1"
  local ssh_hostname=""
  local resolved_host=""

  ssh_hostname="$(ssh -G "$ssh_target" 2>/dev/null | awk '/^hostname / { print $2; exit }')"
  if [[ -z "$ssh_hostname" ]]; then
    ssh_hostname="${ssh_target##*@}"
  fi

  resolved_host="$(__k.importContext_resolve_host_to_ip "$ssh_hostname")"
  if [[ -z "$resolved_host" ]]; then
    printf "${RED}Error:${NC} could not resolve SSH target %s to an IP address\n" "'$ssh_target'" >&2
    return 1
  fi

  print -r -- "$resolved_host"
}

function __k.importContext_name_exists() {
  emulate -L zsh

  local kubeconfig_path="$1"
  local entry_type="$2"
  local entry_name="$3"
  local jsonpath=""

  case "$entry_type" in
  contexts)
    jsonpath='{range .contexts[*]}{.name}{"\n"}{end}'
    ;;
  clusters)
    jsonpath='{range .clusters[*]}{.name}{"\n"}{end}'
    ;;
  users)
    jsonpath='{range .users[*]}{.name}{"\n"}{end}'
    ;;
  *)
    return 1
    ;;
  esac

  kubectl config view --kubeconfig="$kubeconfig_path" -o "jsonpath=$jsonpath" 2>/dev/null | grep -Fx -- "$entry_name" >/dev/null 2>&1
}

function __k.importContext_prepare_destination_kubeconfig() {
  emulate -L zsh

  local source_kubeconfig="$1"
  local output_kubeconfig="$2"
  local entry_name="$3"

  if ! command -v jq >/dev/null 2>&1; then
    printf "jq is required to safely rewrite kubeconfig entries\n" >&2
    return 1
  fi

  kubectl config view --kubeconfig="$source_kubeconfig" --raw -o json | \
    jq -e --indent 2 \
      --arg entry_name "$entry_name" \
      '
      .contexts = ((.contexts // []) | map(select(.name != $entry_name)))
      | .clusters = ((.clusters // []) | map(select(.name != $entry_name)))
      | .users = ((.users // []) | map(select(.name != $entry_name)))
      | if .["current-context"] == $entry_name then
          del(.["current-context"])
        else
          .
        end
      ' > "$output_kubeconfig"
}

function __k.importContext_transform_kubeconfig() {
  emulate -L zsh

  local source_kubeconfig="$1"
  local output_kubeconfig="$2"
  local source_context="$3"
  local new_name="$4"
  local remote_server="$5"
  local ssh_host="$6"

  if ! command -v jq >/dev/null 2>&1; then
    printf "jq is required to safely rename kubeconfig entries\n" >&2
    return 1
  fi

  kubectl --kubeconfig="$source_kubeconfig" --context="$source_context" config view --raw --flatten --minify -o json | \
    jq -e --indent 2 \
      --arg new_name "$new_name" \
      --arg remote_server "$remote_server" \
      --arg ssh_host "$ssh_host" \
      -f /dev/fd/3 > "$output_kubeconfig" 3<<'JQ'
def normalized_host($host):
  if ($host | contains(":")) and (($host | startswith("[")) | not) then
    "[\($host)]"
  else
    $host
  end;

def rewrite_loopback_server($host):
  if . == null or . == "" or $host == "" then
    .
  elif test("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)(127\\.0\\.0\\.1|0\\.0\\.0\\.0|localhost)(?<suffix>([:/].*)?)$") then
    sub(
      "^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)(127\\.0\\.0\\.1|0\\.0\\.0\\.0|localhost)(?<suffix>([:/].*)?)$";
      "\(.scheme)\(normalized_host($host))\(.suffix // "")"
    )
  elif test("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)\\[::1\\](?<suffix>([:/].*)?)$") then
    sub(
      "^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)\\[::1\\](?<suffix>([:/].*)?)$";
      "\(.scheme)\(normalized_host($host))\(.suffix // "")"
    )
  else
    .
  end;

if (.contexts | length) != 1 then
  error("expected exactly one context after minify")
elif (.clusters | length) != 1 then
  error("expected exactly one cluster after minify")
elif ((.contexts[0].context.user // "") == "" and (.users | length) > 0) then
  error("found user entries but the selected context does not reference one")
elif ((.contexts[0].context.user // "") != "" and (.users | length) != 1) then
  error("expected exactly one user after minify")
else
  .contexts[0].name = $new_name
  | .contexts[0].context.cluster = $new_name
  | .["current-context"] = $new_name
  | .clusters[0].name = $new_name
  | if (.contexts[0].context.user // "") != "" then
      .users[0].name = $new_name
      | .contexts[0].context.user = $new_name
    else
      .
    end
  | if $remote_server != "" then
      .clusters[0].cluster.server = $remote_server
    elif $ssh_host != "" then
      .clusters[0].cluster.server |= rewrite_loopback_server($ssh_host)
    else
      .
    end
end
JQ
}

function __k.importContext_usage() {
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  ${CAT_TEXT}k.importContext${NC} ${CAT_OVERLAY1}Import, rename, and merge kubeconfig contexts${NC} ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Usage${NC}"
  echo -e "  ${CAT_GREEN}k.importContext${NC} ${CAT_BLUE}[options]${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Required${NC}"
  echo -e "  ${CAT_GREEN}  -n, --new-name <name>${NC}       ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Target name for context, cluster, and user${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Options${NC}"
  echo -e "  ${CAT_GREEN}  -i, --import <path>${NC}         ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Source kubeconfig path${NC}"
  echo -e "  ${CAT_GREEN}  -d, --destination <path>${NC}    ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Destination kubeconfig ${CAT_OVERLAY0}(default: \$HOME/.kube/config)${NC}"
  echo -e "  ${CAT_GREEN}  -c, --context <name>${NC}        ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Source context to import when the file has many${NC}"
  echo -e "  ${CAT_GREEN}  -s, --ssh-session <target>${NC}  ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Fetch the kubeconfig with scp before processing${NC}"
  echo -e "  ${CAT_GREEN}  -r, --remote-server <url>${NC}   ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Override the imported cluster server URL${NC}"
  echo -e "  ${CAT_GREEN}  -h, --help${NC}                  ${CAT_SURFACE2}│${NC} ${CAT_TEXT}Display this help message${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Behavior${NC}"
  echo -e "  ${CAT_SUBTEXT0}  •${NC} ${CAT_TEXT}Imports one context, renames the context/cluster/user trio, then merges it${NC}"
  echo -e "  ${CAT_SUBTEXT0}  •${NC} ${CAT_TEXT}Defaults to ${CAT_GREEN}~/.kube/config${NC} ${CAT_TEXT}on the remote SSH account when ${CAT_GREEN}--ssh-session${NC} ${CAT_TEXT}is used without ${CAT_GREEN}--import${NC}"
  echo -e "  ${CAT_SUBTEXT0}  •${NC} ${CAT_TEXT}Rewrites loopback server endpoints to the resolved SSH target IP${NC}"
  echo -e "  ${CAT_SUBTEXT0}  •${NC} ${CAT_TEXT}Re-importing the same ${CAT_GREEN}--new-name${NC} ${CAT_TEXT}replaces the existing local entries before merge${NC}"
  echo -e "  ${CAT_SUBTEXT0}  •${NC} ${CAT_TEXT}Backs up the destination kubeconfig to ${CAT_GREEN}<destination>.bak${NC} ${CAT_TEXT}first${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Examples${NC}"
  echo -e "  ${CAT_SAPPHIRE}  k.importContext -i ~/Downloads/dev.yaml -n dev-west${NC}"
  echo -e "  ${CAT_SAPPHIRE}  k.importContext -i ./vendor.yaml -c staging -n vendor-staging${NC}"
  echo -e "  ${CAT_SAPPHIRE}  k.importContext -s rl-mdegarmo1 -n rl-mdegarmo1${NC}"
  echo -e "  ${CAT_SAPPHIRE}  k.importContext -s ops@bastion -i /etc/rancher/k3s/k3s.yaml -n homelab${NC}"
  echo -e "  ${CAT_SAPPHIRE}  k.importContext -s ops@bastion -i /etc/rancher/k3s/k3s.yaml -n homelab -r https://k3s.example.com:6443${NC}"
  echo ""
  echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
  echo -e "  ${CAT_MAUVE}Tip:${NC} ${CAT_TEXT}Use ${CAT_GREEN}--context${NC} ${CAT_TEXT}whenever the source kubeconfig contains multiple contexts and no clear default.${NC}"
  echo ""
}

# A function to take an external kube config file, rename the context,
# cluster, and user names before merging it with the current kube config
function k.importContext() {
  emulate -L zsh

  local dest_kubeconfig="$HOME/.kube/config"
  local import_file=""
  local source_context=""
  local new_name=""
  local ssh_session=""
  local remote_server=""
  local source_kubeconfig=""
  local dest_dir=""
  local backup_path=""
  local tmp_dir=""
  local downloaded_kubeconfig=""
  local prepared_dest_kubeconfig=""
  local transformed_kubeconfig=""
  local merged_kubeconfig=""
  local kubeconfig_chain=""
  local ssh_host=""
  local ssh_label=""
  local remote_import_spec=""
  local -a conflicts

  {
    while [[ $# -gt 0 ]]; do
      case "$1" in
      -d | --destination)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        dest_kubeconfig="$2"
        shift 2
        ;;
      -i | --import)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        import_file="$2"
        shift 2
        ;;
      -c | --context)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        source_context="$2"
        shift 2
        ;;
      -n | --new-name)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        new_name="$2"
        shift 2
        ;;
      -s | --ssh-session)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        ssh_session="$2"
        shift 2
        ;;
      -r | --remote-server)
        if [[ $# -lt 2 ]]; then
          printf "${RED}Error:${NC} %s requires a value\n" "$1" >&2
          return 1
        fi
        remote_server="$2"
        shift 2
        ;;
      -h | --help)
        __k.importContext_usage
        return 0
        ;;
      -* | --*)
        printf "${RED}Error:${NC} invalid option %s\n" "'$1'" >&2
        return 1
        ;;
      *)
        printf "${RED}Error:${NC} invalid argument %s\n" "'$1'" >&2
        return 1
        ;;
      esac
    done

    if [[ -z "$import_file" && -n "$ssh_session" ]]; then
      import_file="~/.kube/config"
    fi

    if [[ -z "$new_name" ]]; then
      printf "${RED}Error:${NC} %s is required\n" "--new-name" >&2
      __k.importContext_usage
      return 1
    fi

    if [[ -z "$import_file" ]]; then
      printf "${RED}Error:${NC} %s is required unless %s is provided\n" "--import" "--ssh-session" >&2
      __k.importContext_usage
      return 1
    fi

    if [[ -n "$remote_server" && "$remote_server" != *://* ]]; then
      printf "${RED}Error:${NC} --remote-server must be a full URL such as https://api.example.com:6443\n" >&2
      return 1
    fi

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/k.importContext.XXXXXX")" || return 1
    downloaded_kubeconfig="$tmp_dir/imported-kubeconfig"
    prepared_dest_kubeconfig="$tmp_dir/prepared-destination-kubeconfig"
    transformed_kubeconfig="$tmp_dir/transformed-kubeconfig"
    merged_kubeconfig="$tmp_dir/merged-kubeconfig"

    if [[ -n "$ssh_session" ]]; then
      ssh_label="${ssh_session##*@}"
      ssh_host="$(__k.importContext_resolve_ssh_host "$ssh_session")" || return 1
      remote_import_spec="${ssh_session}:${import_file}"
      __task "[$ssh_label] Downloading remote kubeconfig"
      if ! _cmd "scp ${(q)remote_import_spec} ${(q)downloaded_kubeconfig}"; then
        return 1
      fi
      _task_done
      source_kubeconfig="$downloaded_kubeconfig"
    else
      source_kubeconfig="$import_file"
    fi

    if [[ ! -f "$source_kubeconfig" ]]; then
      printf "${RED}Error:${NC} kubeconfig not found at %s\n" "$source_kubeconfig" >&2
      return 1
    fi

    source_context="$(__k.importContext_resolve_source_context "$source_kubeconfig" "$source_context")" || return 1

    __task "Preparing context $source_context as $new_name"
    if ! _cmd "__k.importContext_transform_kubeconfig ${(q)source_kubeconfig} ${(q)transformed_kubeconfig} ${(q)source_context} ${(q)new_name} ${(q)remote_server} ${(q)ssh_host}"; then
      return 1
    fi
    _task_done

    dest_dir="${dest_kubeconfig:h}"
    if [[ ! -d "$dest_dir" ]]; then
      __task "Creating destination directory $dest_dir"
      if ! _cmd "mkdir -p ${(q)dest_dir}"; then
        return 1
      fi
      _task_done
    fi

    backup_path="${dest_kubeconfig}.bak"
    if [[ -f "$dest_kubeconfig" ]]; then
      conflicts=()
      if __k.importContext_name_exists "$dest_kubeconfig" contexts "$new_name"; then
        conflicts+=("context")
      fi
      if __k.importContext_name_exists "$dest_kubeconfig" clusters "$new_name"; then
        conflicts+=("cluster")
      fi
      if __k.importContext_name_exists "$dest_kubeconfig" users "$new_name"; then
        conflicts+=("user")
      fi

      if (( ${#conflicts[@]} > 0 )); then
        __task "Replacing existing ${(j:, :)conflicts} entries named $new_name"
        if ! _cmd "__k.importContext_prepare_destination_kubeconfig ${(q)dest_kubeconfig} ${(q)prepared_dest_kubeconfig} ${(q)new_name}"; then
          return 1
        fi
        _task_done
        kubeconfig_chain="$prepared_dest_kubeconfig:$transformed_kubeconfig"
      else
        kubeconfig_chain="$dest_kubeconfig:$transformed_kubeconfig"
      fi

      __task "Backing up destination kubeconfig to $backup_path"
      if ! _cmd "cp ${(q)dest_kubeconfig} ${(q)backup_path}"; then
        return 1
      fi
      _task_done
    else
      kubeconfig_chain="$transformed_kubeconfig"
    fi

    __task "Merging kubeconfig into $dest_kubeconfig"
    if ! _cmd "KUBECONFIG=${(q)kubeconfig_chain} kubectl config view --merge --flatten > ${(q)merged_kubeconfig}"; then
      return 1
    fi
    if ! _cmd "mv ${(q)merged_kubeconfig} ${(q)dest_kubeconfig}"; then
      return 1
    fi
    _task_done

    __task "Kubeconfig imported successfully"
    _task_done
  } always {
    if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
      rm -rf "$tmp_dir"
    fi
  }
}

compdef __k_import_context_complete k.importContext

# k.deleteContext - Clean up kubectl cluster and associated contexts/users
# Usage: k.deleteContext <cluster-name> [--force] [--dry-run]
function k.deleteContext() {
  local cluster_name=""
  local force=false
  local dry_run=false
  local kubeconfig_path="${KUBECONFIG:-$HOME/.kube/config}"
  local backup_dir="$HOME/.kube/backups"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --help|-h)
        __k.deleteContext_usage
        return 0
        ;;
      *)
        if [[ -z "$cluster_name" ]]; then
          cluster_name="$1"
        else
          echo -e "${RED}Error: Multiple cluster names provided${NC}"
          __k.deleteContext_usage
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$cluster_name" ]]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    __k.deleteContext_usage
    return 1
  fi

  # Verify kubeconfig exists
  if [[ ! -f "$kubeconfig_path" ]]; then
    echo -e "${RED}Error: kubeconfig not found at $kubeconfig_path${NC}"
    return 1
  fi

  # Dry run banner
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}         DRY RUN MODE - NO CHANGES     ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
  fi

  # Check if cluster exists
  if ! kubectl config get-clusters | grep -q "^${cluster_name}$"; then
    echo -e "${RED}Error: Cluster '${cluster_name}' not found${NC}"
    echo ""
    echo "Available clusters:"
    kubectl config get-clusters
    return 1
  fi

  # Find contexts using this cluster
  echo -e "${YELLOW}Finding contexts for cluster: ${cluster_name}${NC}"
  local contexts=$(kubectl config get-contexts -o name | while read -r context; do
    local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.cluster}")
    if [[ "$cluster" == "$cluster_name" ]]; then
      echo "$context"
    fi
  done)

  local context_count=0
  if [[ -z "$contexts" ]]; then
    echo "No contexts found for this cluster"
  else
    context_count=$(echo "$contexts" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $context_count context(s):${NC}"
    echo "$contexts" | sed 's/^/  - /'
  fi

  # Find users from those contexts
  echo ""
  echo -e "${YELLOW}Finding users associated with contexts...${NC}"
  local users=""
  if [[ -n "$contexts" ]]; then
    users=$(echo "$contexts" | while read -r context; do
      kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.user}"
      echo ""
    done | sort -u | grep -v '^$')
  fi

  local user_count=0
  if [[ -z "$users" ]]; then
    echo "No users found"
  else
    user_count=$(echo "$users" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $user_count user(s):${NC}"
    echo "$users" | sed 's/^/  - /'
  fi

  # Check which users would actually be deleted (not used by other contexts)
  echo ""
  echo -e "${YELLOW}Checking user dependencies...${NC}"
  local users_to_delete=""
  local users_to_keep=""
  if [[ -n "$users" ]]; then
    while IFS= read -r user; do
      local other_contexts=$(kubectl config get-contexts -o name | while read -r ctx; do
        local ctx_cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$ctx')].context.cluster}")
        local ctx_user=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$ctx')].context.user}")
        if [[ "$ctx_user" == "$user" ]] && [[ "$ctx_cluster" != "$cluster_name" ]]; then
          echo "$ctx"
        fi
      done)

      if [[ -z "$other_contexts" ]]; then
        users_to_delete="${users_to_delete}${user}"$'\n'
      else
        users_to_keep="${users_to_keep}${user}"$'\n'
      fi
    done <<< "$users"

    # Clean up trailing newlines
    users_to_delete=$(echo "$users_to_delete" | grep -v '^$' || true)
    users_to_keep=$(echo "$users_to_keep" | grep -v '^$' || true)
  fi

  # Summary
  echo ""
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}=== Deletion Preview (DRY RUN) ===${NC}"
  else
    echo -e "${YELLOW}=== Deletion Summary ===${NC}"
  fi
  echo ""
  echo -e "Cluster to delete:  ${RED}$cluster_name${NC}"
  echo ""
  if [[ $context_count -gt 0 ]]; then
    echo -e "Contexts to delete: ${RED}$context_count${NC}"
    echo "$contexts" | sed 's/^/  - /'
  else
    echo -e "Contexts to delete: ${RED}0${NC}"
  fi
  echo ""

  local delete_count=0
  if [[ -n "$users_to_delete" ]]; then
    delete_count=$(echo "$users_to_delete" | wc -l | tr -d ' ')
    echo -e "Users to delete:    ${RED}$delete_count${NC}"
    echo "$users_to_delete" | sed 's/^/  - /'
  else
    echo -e "Users to delete:    ${RED}0${NC}"
  fi

  if [[ -n "$users_to_keep" ]]; then
    local keep_count=$(echo "$users_to_keep" | wc -l | tr -d ' ')
    echo ""
    echo -e "Users to keep (used by other clusters): ${GREEN}$keep_count${NC}"
    echo "$users_to_keep" | sed 's/^/  - /'
  fi
  echo ""

  # Exit if dry run
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DRY RUN COMPLETE - NO CHANGES MADE  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "To perform the actual deletion, run without --dry-run:"
    echo "  k.deleteContext $cluster_name"
    return 0
  fi

  # Confirmation
  if [[ "$force" == false ]]; then
    echo -e "${YELLOW}This will delete the cluster, all associated contexts, and unused users.${NC}"
    echo -n "Do you want to proceed? (yes/no): "
    read REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
      echo "Aborted."
      return 0
    fi
  fi

  # Create backup directory
  mkdir -p "$backup_dir"

  # Create backup
  local backup_file="$backup_dir/config.$(date +%Y%m%d_%H%M%S).backup"
  echo -e "${YELLOW}Creating backup...${NC}"
  cp "$kubeconfig_path" "$backup_file"
  echo -e "${GREEN}✓ Backup saved to: $backup_file${NC}"
  echo ""

  # Delete contexts
  if [[ -n "$contexts" ]]; then
    echo -e "${YELLOW}Deleting contexts...${NC}"
    echo "$contexts" | while read -r context; do
      if kubectl config delete-context "$context" &>/dev/null; then
        echo -e "${GREEN}✓ Deleted context: $context${NC}"
      else
        echo -e "${RED}✗ Failed to delete context: $context${NC}"
      fi
    done
    echo ""
  fi

  # Delete cluster
  echo -e "${YELLOW}Deleting cluster...${NC}"
  if kubectl config delete-cluster "$cluster_name" &>/dev/null; then
    echo -e "${GREEN}✓ Deleted cluster: $cluster_name${NC}"
  else
    echo -e "${RED}✗ Failed to delete cluster: $cluster_name${NC}"
  fi
  echo ""

  # Delete users
  if [[ -n "$users_to_delete" ]]; then
    echo -e "${YELLOW}Deleting users...${NC}"
    echo "$users_to_delete" | while read -r user; do
      if kubectl config delete-user "$user" &>/dev/null; then
        echo -e "${GREEN}✓ Deleted user: $user${NC}"
      else
        echo -e "${RED}✗ Failed to delete user: $user${NC}"
      fi
    done
  fi

  if [[ -n "$users_to_keep" ]]; then
    echo ""
    echo -e "${YELLOW}Skipped users (still used by other clusters):${NC}"
    echo "$users_to_keep" | sed 's/^/  ⊘ /'
  fi

  echo ""
  echo -e "${GREEN}=== Cleanup Complete ===${NC}"
  echo ""
  echo "To restore from backup:"
  echo "  cp $backup_file $kubeconfig_path"
}

# Usage helper function
function __k.deleteContext_usage() {
  echo -e "${BOLD}USAGE${NC}"
  echo "    k.deleteContext <cluster-name> [options]"
  echo ""
  echo -e "${BOLD}DESCRIPTION${NC}"
  echo "    Clean up a kubectl cluster and all associated contexts and users."
  echo ""
  echo -e "${BOLD}OPTIONS${NC}"
  echo "    --force       Skip confirmation prompt"
  echo "    --dry-run     Show what would be deleted without actually deleting"
  echo "    -h, --help    Display this help message"
  echo ""
  echo -e "${BOLD}EXAMPLES${NC}"
  echo "    k.deleteContext my-cluster --dry-run"
  echo "    k.deleteContext my-cluster"
  echo "    k.deleteContext production-cluster --force"
  echo ""
  echo "The function will:"
  echo "  1. Create a backup of your kubeconfig (unless --dry-run)"
  echo "  2. Find all contexts using the cluster"
  echo "  3. Find all users associated with those contexts"
  echo "  4. Delete the cluster, contexts, and users"
  echo ""
  echo "Backups are stored in: \$HOME/.kube/backups"
}

# Tab completion for k.deleteContext (ZSH native style like in .raftrc)
function _k.deleteContext() {
  local -a clusters
  clusters=(${(f)"$(kubectl config get-clusters 2>/dev/null | grep -v NAME)"})

  _arguments \
    '1:cluster:(($clusters))' \
    '(--force)--force[Skip confirmation prompt]' \
    '(--dry-run)--dry-run[Show what would be deleted without actually deleting]' \
    '(-h --help)'{-h,--help}'[Display help message]'
}

# Register the completion function with compdef (ZSH native)
compdef _k.deleteContext k.deleteContext

# complete -o nospace -F __kc_complete kc
complete -o nospace -F __kgnonly_complete k.node.debug k.node.exec
# complete -o nospace -F __kgnsonly_complete kns
complete -W "master worker etcd control-plane" kgnonly kgnonly.allCluster
