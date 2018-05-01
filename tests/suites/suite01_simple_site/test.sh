#!/bin/bash

suite_name="Simple site"

test_domain="example.test"

function prepare_suite() {
  log_notice 1 "Deploying test site code."
  $docker_exec test -L /var/vhosts/$test_domain ||
    $docker_exec ln -s /var/tvhosts/site1 /var/vhosts/$test_domain

  log_notice 1 "Adding container IP to /etc/hosts"
  add_domain_to_etc_hosts $test_domain
}

function execute_suite() {
  test_role_idempotence

  test_nginx_is_running

  test_site_is_up "http://$test_domain" "This is the test site number 1."
}
