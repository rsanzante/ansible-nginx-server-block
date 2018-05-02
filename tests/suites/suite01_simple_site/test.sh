#!/bin/bash

suite_name="Simple site"

test_domain="example.test"

function prepare_suite() {
  log_notice 1 "Deploying test site code."
  prepare_suite  $test_domain site1
}

function execute_suite() {
  test_role_idempotence

  test_nginx_is_running

  test_site_is_up "http://$test_domain" "This is the test site number 1."
}
