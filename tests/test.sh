#!/bin/bash

set -e
set -u

# Functions
###########

function usage() {
  echo "

Launch test for this role.

Usage:

  $SCRIPT_NAME [OPTIONS]

  Options:
    -v|--verbose: Increase verbose level. Use as many times as you want.
    -d|--distro: Distro name to use. Can be set also with a \$distro_name env variable.
    -c|--container-id: Do not setup a container, use the container with the container id provided.
    -k|--keep-container: Do not destroy container when tests ends.
    -n|--dry-mode: Do not make any operations, just show what would be done.
    -h|--help: Show this help message.
"
}

initializeANSI()
{
  esc=""

  blackf="${esc}[30m";   redf="${esc}[31m";    greenf="${esc}[32m"
  yellowf="${esc}[33m"   bluef="${esc}[34m";   purplef="${esc}[35m"
  cyanf="${esc}[36m";    whitef="${esc}[37m"

  blackb="${esc}[40m";   redb="${esc}[41m";    greenb="${esc}[42m"
  yellowb="${esc}[43m"   blueb="${esc}[44m";   purpleb="${esc}[45m"
  cyanb="${esc}[46m";    whiteb="${esc}[47m"

  boldon="${esc}[1m";    boldoff="${esc}[22m"
  italicson="${esc}[3m"; italicsoff="${esc}[23m"
  ulon="${esc}[4m";      uloff="${esc}[24m"
  invon="${esc}[7m";     invoff="${esc}[27m"
  blon="${esc}[5m";      bloff="${esc}[25m"

  reset="${esc}[0m"
}

function set_params_per_distro() {
  # CentOS 7
  if [ $distro_name = 'centos7' ]; then
    init="/usr/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="yum"
    pre_install_cmd="yum install epel-release -y"
    packages="nginx"
    ansible_extra_vars="-e nsb_nginx_sites_available_path=conf.d -e nsb_nginx_sites_enabled_path=conf.d -e nsb_distro_allows_disabling_sites=False"
  # Ubuntu 18.04
  elif [ $distro_name = 'ubuntu1804' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="apt-get"
    packages="nginx-full curl"
  # Ubuntu 16.04
  elif [ $distro_name = 'ubuntu1604' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="apt-get"
    packages="nginx-full curl"
  # Ubuntu 14.04
  elif [ $distro_name = 'ubuntu1404' ]; then
    init="/sbin/init"
    opts="--privileged"
    pmanager="apt-get"
    packages="nginx-full curl"
  # Debian 9
  elif [ $distro_name = 'debian9' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="apt-get"
    packages="nginx-full procps curl"
  # Debian 8
  elif [ $distro_name = 'debian8' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="apt-get"
    packages="nginx-full curl"
  # Fedora 24
  elif [ $distro_name = 'fedora24' ]; then
    init="/usr/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="yum"
    packages="nginx procps"
    ansible_extra_vars="-e nsb_nginx_sites_available_path=conf.d -e nsb_nginx_sites_enabled_path=conf.d -e nsb_distro_allows_disabling_sites=False"
  # Fedora 27
  elif [ $distro_name = 'fedora27' ]; then
    init="/usr/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    pmanager="yum"
    packages="nginx procps"
    ansible_extra_vars="-e nsb_nginx_sites_available_path=conf.d -e nsb_nginx_sites_enabled_path=conf.d -e nsb_distro_allows_disabling_sites=False"
  else
    err "Unkown distro name: $distro_name"
  fi

}

# Logs a message if equal or greater than current verbose level.
# $1 Message log level.
# $2 Message to display.
function log_msg() {
  level=$1
  shift;
  if [ "$VERBOSE_LEVEL" -ge $level ]
  then
    printf "$1"
  fi
}

# Displays an error messages and exits with error.
# $1 Error to display.
function err() {
  log_msg 0 "${redf}Error!${reset} $1\n"
  exit -1
}

# Displays a section header.
# $1 Header name.
function log_header() {
  log_msg 0 "\n${ulon}${boldon}${greenf}${1}${reset}\n"
}

# Displays a test suite header.
# $1 Test suite name.
function log_suite_header() {
  log_msg 0 "\n${boldon}${yellowf}${1}${reset}\n"
}

# Displays a log notice.
# $1 Log level.
# $2 Notice to display.
function log_notice() {
  level=$1
  indentation=$(( $level == 0 ? 0 : level-1 ))
  indentation_str=$(printf %${indentation}s)
  shift
  log_msg $level "${indentation_str}${greenf}${1}${reset}\n"
}

# Displays a not executed command (becasue of dry mode on).
# $* Command that hasn't been executed
function log_cmd_dm() {
  log_msg 0 "${cyanf}${italicson}(commnad that would be run)${reset} ${*}\n"
}

# Displays a command that is going to be executed.
# $* Command to be executed.
function log_cmd() {
  log_msg 3 "${cyanf}${italicson}${*}${reset}\n"
}

# Displays a test name.
# $1 Test name to display.
function log_test() {
  log_msg 0 "\n${yellowf}${*}${reset}\n"
}

function log_ansible_version() {
  log_header "Ansible info"
  $docker_exec ansible --version
}

function run_cmd() {
  log_cmd $*
  $*
}

# Displays a test result, and exit with error if test failed.
# $1 Value returned by test. 0 menas ok, 1 error.
function process_test_result() {
  if [ $1 -eq 0 ]
  then
    log_msg 0 "${boldon}${greenf}PASS!${reset}\n"
  else
    log_msg 0 "${boldon}${redf}ERROR!${reset}\n"
    exit -1
  fi
}

# Adds a/multiple domain(s) to local machine /etc/hosts using container IP.
# $1 Domain(s) to add
function add_domain_to_etc_hosts() {
  if [ $DRY_MODE -eq 0 ]
  then
    echo "$container_ip $1" | sudo tee -a /etc/hosts > /dev/null
  else
    $simcom echo "$container_ip $1" \| sudo tee -a /etc/hosts  \> /dev/null
  fi
  add_lines_to_etc_hosts=$((add_lines_to_etc_hosts+1))

  # Add inside container as well.
  $docker_exec  /bin/sh -c  "echo 127.0.0.1 $1 >> /etc/hosts"

}

# Remove all added domains to local machine /etc/hosts.
function remove_added_lines_to_etc_hosts() {
  if [ $DRY_MODE -eq 0 ]
  then
    head -n -$add_lines_to_etc_hosts /etc/hosts | sudo tee /etc/hosts.tmp > /dev/null
    sudo chmod 0644 /etc/hosts.tmp
    sudo mv /etc/hosts.tmp /etc/hosts
  else
    $simcom head -n -$add_lines_to_etc_hosts /etc/hosts \| sudo tee /etc/hosts.tmp \> /dev/null
    $simcom sudo chmod 0644 /etc/hosts.tmp
    $simcom sudo mv /etc/hosts.tmp /etc/hosts
  fi
}

# Detects test suites and launches them.
function discover_test_suites() {
  suites_path=$(ls -d $TEST_SUITES_DIR/*)

  for suite_path in $suites_path
  do
    run_suite
  done
}

function run_suite () {

  # Load test configuration.
  source "$suite_path/test.sh"

  log_suite_header "Suite: $suite_name"

  # Prepare container.
  if [ $REUSE_CONTAINER -eq 0 ]; then prepare_docker_container $docker_image; fi
  post_prepare_docker_container

  # Log Ansible info.
  log_ansible_version

  if [ $DRY_MODE -eq 1 ]
  then
    log_notice 0 "Not performing test because dry mode is enabled."
  else
    perform_tests
  fi

  if [ $KEEP_CONTAINER -eq 0 ]
  then
    remove_docker_container
  else
    log_msg 0 "Keeping container as instructed. Container id: $container_id"
  fi

  remove_added_lines_to_etc_hosts

  log_notice 0 "\n${boldon}${greenf}All tests passed!${reset}\n"
}

# Detects test playbooks designed to fail and launches them.
# Instead of create a new container reuse a new container for all error
# tests. Just to try new thigs :D.
function discover_test_error_playbooks() {
  playbook_paths=$(ls -1 $TEST_ERROR_PLAYBOOKS_DIR/*.yml)

  log_header "Testing playbooks with invalid conf."

  # Prepare container.
  if [ $REUSE_CONTAINER -eq 0 ]; then prepare_docker_container $docker_image; fi
  post_prepare_docker_container

  if [ $DRY_MODE -eq 1 ]
  then
    log_notice 0 "Not performing test because dry mode is enabled."
  else
    for playbook_path in $playbook_paths
    do
      run_error_playbook
    done
  fi

  if [ $KEEP_CONTAINER -eq 0 ]
  then
    remove_docker_container
  else
    log_msg 0 "Keeping container as instructed. Container id: $container_id"
  fi

  remove_added_lines_to_etc_hosts
}

function run_error_playbook () {
  # Disable error trap because command should return error.
  set +e

  error_playbook_title=$(basename "$playbook_path" .yml)

  log_test "Playbook: $error_playbook_title"

  output=$(run_cmd $docker_exec env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/roles/metadrop.nginx_server_block/"$playbook_path" $ansible_extra_vars)
  echo "$output" >&6

  echo "$output" | grep -q '.*failed=1' \
    && test_rc=0 \
    || test_rc=1

  set -e
  process_test_result $test_rc
}

# Prepares docker image from a distro name.
#
# $1: Distro name.
# Set var:
#   docker_image_name: Docker image name to use.
function initialize_docker_image() {
  docker_image="geerlingguy/docker-$1-ansible:latest"
  log_header "Initializating docker image $docker_image"
  $simcom docker pull $docker_image
}

# Runs a container from current image and prepare it for tests.
# $1 Docker image to use.
# Set var:
#  container_id: Id of created container.
function prepare_docker_container() {

  container_id="${distro_name}_$(date +%s)"

  log_header "Preparing docker container $container_id"

  log_notice 1 "Bring container up"
  docker run --detach --name $container_id --privileged \
         --volume="$PWD":/etc/ansible/roles/metadrop.nginx_server_block:rw \
         --volume="$PWD/tests/conf":/etc/testconf:ro \
         --volume="$PWD/tests/sites":/var/tvhosts:ro \
         -p 127.0.0.1:80:80 \
         $opts \
         $1 $init

  post_prepare_docker_container

  log_notice 1 "Installing Nginx server from system packages"

  log_notice 2 "Updating package list"

  run_cmd $docker_exec $pmanager update -y
  if [ ! -z "$pre_install_cmd" ]; then run_cmd $docker_exec $pre_install_cmd; fi

  log_notice 2 "Installing Nginx"
  run_cmd $docker_exec $pmanager install $packages -y

  log_notice 2 "Create directory for vhosts"
  $docker_exec mkdir /var/vhosts/
}

# Based on https://stackoverflow.com/a/20686101/907592
function post_prepare_docker_container() {
  docker_exec="$simcom docker exec $container_id"

  log_notice 2 "Obtaining container IP"
  container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_id)

  # If nothing retrieved try old docker format.
  if [ -z "$container_ip" ]; then container_ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}'  $container_id); fi
}

# Delete created docker container.
function remove_docker_container() {
  log_header "Removing container $container_id"
  $simcom docker rm -f $container_id > /dev/null
}

# Prepares a domain for test creating a symlink to its code and adding it to
# /etc/hosts.
function prepare_domain() {
  $docker_exec test -L /var/vhosts/$1 ||
    $docker_exec ln -s /var/tvhosts/$2 /var/vhosts/$1

  log_notice 1 "Adding container IP to /etc/hosts with domain $1"
  add_domain_to_etc_hosts $1
}

function perform_tests() {

  log_header "Preparing suite"
  prepare_suite

  log_notice 0 "Running ansible role"
  # Set ANSIBLE_FORCE_COLOR instead of using `--tty`
  # See https://www.jeffgeerling.com/blog/2017/fix-ansible-hanging-when-used-docker-and-tty
  output=$(run_cmd $docker_exec env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/roles/metadrop.nginx_server_block/$suite_path/test.yml $ansible_extra_vars)

  echo "$output" >&6

  echo $output | grep -q '.*failed=0' \
    || err "Error running Ansible playbook"

  log_msg 2 "Environment configuration"

  # DEBUG
  set +e
  output=$(run_cmd $docker_exec cat /etc/nginx/sites-enabled/restriction-example3.test.conf)
  echo "$output" >&6
  set -e




  log_header "Starting tests"
  execute_suite
}

# Tests role doesn't change anything on second run.
function test_role_idempotence() {
  log_test "Test role idempotence."

  $docker_exec env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/roles/metadrop.nginx_server_block/$suite_path/test.yml $ansible_extra_vars| \
    grep -q 'changed=0.*failed=0' \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}

# Test if nginx is runing.
function test_nginx_is_running() {
  log_test "Test Nginx server is running."

  output=$(docker exec ${container_id} ps -ax)
  echo "$output" >&6

  echo "$output" | grep -q 'nginx' \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}

# Test a given domain returns a given string.
# $1 Domain to test.
# $2 String to match in site HTML.
# $3 Additional curl params
# $4 Local or remote: 0 test is launched from host, 1 test is launched inside
# docker contanier, so cnonectin is local. From host by default.
function test_site_text() {
  local=${4:-0}
  if [ $local -eq 0 ]
  then
    curl_command="curl"
  else
    curl_command="$docker_exec curl"
  fi
  curl_params=${3:-""}

  output=$(run_cmd $curl_command -s "$1" $curl_params)
  echo "$output" >&6

  echo "$output" | grep -q "$2" \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}
# Test a given domain is up.
# $1 Domain to test.
# $2 String to match in site HTML to consider site up.
function test_site_is_up() {
  log_test "Test site '$1' is up."
  test_site_text "$1" "$2"
}

# Test a given domain is Basic Auth protected.
# $1 Domain to test.
function test_site_is_protected() {
  log_test "Test site '$1' is protected by Basic Auth."
  test_site_text "$1" "401 Authorization Required"
}

# Test a given domain is Basic Auth protected.
# $1 Domain to test.
function test_site_is_forbidden() {
  log_test "Test site '$1' is forbidden."
  test_site_text "$1" "403 Forbidden"
}

# Test a given domain returns a given string using Authorization header.
# $1 Domain to test.
# $2 String to match in site HTML.
# $3 User
# $4 Pass
function test_site_is_up_with_credentials() {
  log_test "Test site '$1' can be reached using Basic Auth credentials."
  test_site_text "$1" "$2" "--user $3:$4"
}
# Test a given domain returns a given string using Authorization header.
# $1 Domain to test.
# $2 String to match in site HTML.
# $3 User
# $4 Pass
function test_site_is_up_from_localhost() {
  log_test "Test site '$1' can be reached using local connection."
  test_site_text "$1" "$2" "" 1
}




# Script body
#############

# Config variables.
VERBOSE_LEVEL=0
DRY_MODE=0
REUSE_CONTAINER=0
KEEP_CONTAINER=0
TEST_SUITES_DIR="tests/suites"
TEST_ERROR_PLAYBOOKS_DIR="tests/error_suites"


# Get script name.
SCRIPT_NAME=`basename "$0"`

# Initialize vars.
add_lines_to_etc_hosts=0
simcom=""
pre_install_cmd=""
ansible_extra_vars=""

# Initialize additional output handle.
exec 6>/dev/null

initializeANSI


# Parse options.
OPTS=`getopt -o hvd:nc:kp:m: --long verbose,distro,help,dry-mode,container-id,keep-container,packages,pmanager  -n "$SCRIPT_NAME" -- "$@"`
if [ $? != 0 ]
then
  echo "Failed parsing options." >&2
  exit 1
fi
eval set -- "$OPTS"

# Extract options and their arguments into variables.
while true ; do
  case "$1" in
    -v|--verbose) VERBOSE_LEVEL=$((VERBOSE_LEVEL+1)); shift ;;
    -d|--distro) distro_name=$2; shift 2 ;;
    -c|--container-id) container_id=$2; REUSE_CONTAINER=1 ; shift 2 ;;
    -k|--keep-container) KEEP_CONTAINER=1; shift ;;
    -n|--dry-mode) simcom="log_cmd_dm"; DRY_MODE=1; shift ;;
    -h|--help) usage ; exit -1;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit -1 ;;
  esac
done

# Allow to set distro from env variable.
distro_name=${distro_name:-""}

# Check mandatory  distro name param.
if [ -z "$distro_name" ]; then err "Distro name not provided."; fi

set_params_per_distro

# If verbose level is greater than 1 show output of certain commands.
# See https://serverfault.com/a/414845/324348
if [ $VERBOSE_LEVEL -ge 2 ]; then exec 6>&1; fi

# Report dry mode.
if [ $DRY_MODE -eq 1 ]; then log_notice 0 "Using simulate mode, not commands are executed."; fi


log_msg 1 "Log level: $VERBOSE_LEVEL\n"
log_msg 1 "Using distro '$distro_name'\n"
log_msg 1 "Pacakges to install: '$packages'\n"

# Initialize docker image.
if [ $REUSE_CONTAINER -eq 0 ]; then initialize_docker_image $distro_name; fi

discover_test_suites

discover_test_error_playbooks

log_notice 0 "\n\nEverything is awesome!"

