# Variables
export tick="✓"
export cross="✗"
export curl_opts=(-sL)
export old_versions="5.[3-5]"
export jit_versions="8.[0-9]"
export nightly_versions="8.[2-9]"
export xdebug3_versions="7.[2-4]|8.[0-9]"
export latest="releases/latest/download"
export github="https://github.com/shivammathur"
export jsdeliver="https://cdn.jsdelivr.net/gh/shivammathur"
export setup_php="https://setup-php.com"

# Function to log start of a operation.
step_log() {
  message=$1
  printf "\n\033[90;1m==> \033[0m\033[37;1m%s\033[0m\n" "$message"
}

# Function to log result of a operation.
add_log() {
  mark=$1
  subject=$2
  message=$3
  if [ "$mark" = "$tick" ]; then
    printf "\033[32;1m%s \033[0m\033[34;1m%s \033[0m\033[90;1m%s\033[0m\n" "$mark" "$subject" "$message"
  else
    printf "\033[31;1m%s \033[0m\033[34;1m%s \033[0m\033[90;1m%s\033[0m\n" "$mark" "$subject" "$message"
    [ "$fail_fast" = "true" ] && exit 1
  fi
}

# Function to read env inputs.
read_env() {
  [[ -z "${update}" ]] && update='false' && UPDATE='false' || update="${update}"
  [ "$update" = false ] && [[ -n ${UPDATE} ]] && update="${UPDATE}"
  [[ -z "${runner}" ]] && runner='github' && RUNNER='github' || runner="${runner}"
  [ "$runner" = false ] && [[ -n ${RUNNER} ]] && runner="${RUNNER}"
  [[ -z "${fail_fast}" ]] && fail_fast='false' || fail_fast="${fail_fast}"
}

# Function to download a file using cURL.
# mode: -s pipe to stdout, -v save file and return status code
# execute: -e save file as executable
get() {
  mode=$1
  execute=$2
  file_path=$3
  shift 3
  links=("$@")
  if [ "$mode" = "-s" ]; then
    sudo curl "${curl_opts[@]}" "${links[0]}"
  else
    for link in "${links[@]}"; do
      status_code=$(sudo curl -w "%{http_code}" -o "$file_path" "${curl_opts[@]}" "$link")
      [ "$status_code" = "200" ] && break
    done
    [ "$execute" = "-e" ] && sudo chmod a+x "$file_path"
    [ "$mode" = "-v" ] && echo "$status_code"
  fi
}

# Function to download and run scripts from GitHub releases with jsdeliver fallback.
run_script() {
  repo=$1
  shift
  args=("$@")
  get -q -e /tmp/install.sh "$github/$repo/$latest/install.sh" "$jsdeliver/$repo@main/scripts/install.sh" "$setup_php/$repo/install.sh"
  bash /tmp/install.sh "${args[@]}"
}

# Function to install required packages on self-hosted runners.
self_hosted_setup() {
  if [ "$runner" = "self-hosted" ]; then
    if [[ "${version:?}" =~ $old_versions ]]; then
      add_log "$cross" "PHP" "PHP $version is not supported on self-hosted runner"
      exit 1
    else
      self_hosted_helper >/dev/null 2>&1
    fi
  fi
}

# Function to configure PHP
configure_php() {
  (
    echo -e "date.timezone=UTC\nmemory_limit=-1"
    [[ "$version" =~ $jit_versions ]] && echo -e "opcache.enable=1\nopcache.jit_buffer_size=256M\nopcache.jit=1235"
    [[ "$version" =~ $xdebug3_versions ]] && echo -e "xdebug.mode=coverage"
  ) | sudo tee -a "${pecl_file:-${ini_file[@]}}" >/dev/null
}

# Function to get PHP version in semver format.
php_semver() {
  php -v | grep -Eo -m 1 "[0-9]+\.[0-9]+\.[0-9]+((-?[a-zA-Z]+([0-9]+)?)?){2}" | head -n 1
}

# Function to get the tag for a php version.
php_src_tag() {
  commit=$(php_extra_version | grep -Eo "[0-9a-zA-Z]+")
  if [[ -n "${commit}" ]]; then
    echo "$commit"
  else
    echo "php-${semver:?}"
  fi
}