#!/bin/bash

suite_name="Restrictions"

function prepare_suite() {
  log_notice 1 "Deploying test site code."
  $docker_exec test -L /var/vhosts/$TEST_DOMAIN ||
    $docker_exec ln -s /var/tvhosts/site1 /var/vhosts/$TEST_DOMAIN
}

function execute_suite() {
  test_role_idempotence

  test_nginx_is_running

  test_site_is_up "http://$TEST_DOMAIN" "This is the test site number 1."
}
