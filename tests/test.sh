#!/bin/bash

set -e

# Functions
###########

function usage() {
  echo "
Usage:

  $SCRIPT_NAME
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

# Logs a message if equal or greater than ucrrent verbose level.
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

# Displays a log notice.
# $1 Notice to display.
function log_notice() {
  level=$1
  indentation=$(( $level == 0 ? 0 : level-1 ))
  indentation_str=$(printf %${indentation}s)
  shift
  log_msg $level "${indentation_str}${greenf}${1}${reset}\n"
}

# Displays a not executed command (becasue of dry mode on).
# $* Command that hasn't been executed
function log_cmd() {
  log_msg 0 "${cyanf}${italicson}(commnad that would be run)${reset} ${*}\n"
}

# Displays a test name.
# $1 Test name to display.
function log_test() {
  log_msg 0 "\n${yellowf}${*}${reset}\n"
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

# Prepares docker image from a distro name.
#
# $1: Distro name.
# Set var:
#   docker_image_name: Docker image name to use.
function initialize_docker_image() {
  docker_image="williamyeh/ansible:$1"
  log_header "Initializating docker image $docker_image"
  $simcom docker pull $docker_image
}

# Runs a contanier from current image and prepare it for tests.
# $1 Docker image to use.
# Set var:
#  container_id: Id of created container.
function prepare_docker_container() {

  container_id="${distro_name}_$(date +%s)"

  log_header "Preparing docker container $container_id"

  log_notice 1 "Bring container up"
  $simcom docker run --detach -it \
    --volume="$PWD":/etc/ansible/roles/metadrop.nginx_server_block:rw \
    --volume="$PWD/tests/test_sites":/var/tvhosts:ro \
    --name $container_id $1 bash

  log_notice 1 "Installing Nginx server from system packages"

  log_notice 2 "Updating apt cache"
  $simcom docker exec $container_id sudo apt-get update

  log_notice 2 "Installing Nginx using apt"
  $simcom docker exec $container_id sudo apt-get install nginx-full -y

  log_notice 2 "Adding container IP to /etc/hosts"
  container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_id)
  add_domain_to_etc_hosts $container_ip "mydomain.org"
}

# Delete created docker container.
function remove_docker_container() {
  log_header "Removing container $container_id"
  $simcom docker rm -f $container_id > /dev/null
}

function perform_tests() {

  log_header "Preparing tests"

  log_notice 1 "Deploying test site code."
  $simcom docker exec $container_id sudo mkdir /var/vhosts/
  $simcom docker exec $container_id sudo ln -s /var/tvhosts/site1 /var/vhosts/mydomain.com

  log_notice 0 "Runing ansible role"
  $simcom docker exec --tty $container_id env TERM=xterm ansible-playbook /etc/ansible/roles/metadrop.nginx_server_block/tests/test.yml

  log_header "Starting tests"

  test_role_idempotence

  test_nginx_is_running

  test_site_is_up "http://mydomain.com" "This is the test site number 1."
}

# Tests role doesn't change anything on second run.
function test_role_idempotence() {
  log_test "Test role idempotence."

  docker exec --tty $container_id env TERM=xterm ansible-playbook /etc/ansible/roles/metadrop.nginx_server_block/tests/test.yml | \
    grep -q 'changed=0.*failed=0' \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}

# Test if nginx is runing.
function test_nginx_is_running() {
  log_test "Test Nginx server is running."

  docker exec ${container_id} ps -ax | grep -q 'nginx' \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}

# Test a given domain is up.
# $1 Domain to test.
# $2 String to match in site HTML to consider site up.
function test_site_is_up() {

  log_test "Test site '$1' is up."

  curl -s "$1" | grep -q "$2" \
    && test_rc=0 \
    || test_rc=1

  process_test_result $test_rc
}

# Script body
#############


# Initial flags
VERBOSE_LEVEL=0
DRY_MODE=0
REUSE_CONTAINER=0
KEEP_CONTAINER=0

# Get script name.
SCRIPT_NAME=`basename "$0"`

# Initialize vars.
add_lines_to_etc_hosts=0

initializeANSI

# Parse options.
OPTS=`getopt -o hvd:nc:k --long verbose,distro,help,dry-mode,container-id,keep-container  -n "$SCRIPT_NAME" -- "$@"`
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
    -d|--distro) distro_name=$2 ; shift 2 ;;
    -c|--container-id) container_id=$2; REUSE_CONTAINER=1 ; shift 2 ;;
    -k|--keep-container) KEEP_CONTAINER=1; shift ;;
    -n|--dry-mode) simcom="log_cmd"; DRY_MODE=1; shift ;;
    -h|--help) usage ; exit -1;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit -1 ;;
  esac
done

# Check mandatory params
if [ -z $distro_name ]; then err "Distro name not provided."; fi

if [ $DRY_MODE -eq 1 ]; then log_notice 0 "Using simulate mode, not commands are executed."; fi


log_msg 1 "Log level: $VERBOSE_LEVEL\n"
log_msg 1 "Using distro '$distro_name'\n"


if [ $REUSE_CONTAINER -eq 0 ]; then initialize_docker_image $distro_name; fi


if [ $REUSE_CONTAINER -eq 0 ]; then prepare_docker_container $docker_image; fi


if [ $DRY_MODE -eq 1 ]
then
  log_notice 0 "Not performing test because dry mode is enabled."
else
  perform_tests
fi

if [ $KEEP_CONTAINER -eq 0 ]; then remove_docker_container; fi

remove_added_lines_to_etc_hosts

log_notice 0 "\n${boldon}${greenf}All tests passed!${reset}\n"