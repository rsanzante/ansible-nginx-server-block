#!/bin/bash

suite_name="Restrictions"

test_domain1="restriction-example1.test"
test_domain2="restriction-example2.test"
test_domain3="restriction-example3.test"

function prepare_suite() {
  log_notice 1 "Deploying test site code."
  prepare_domain $test_domain1 site2
  prepare_domain $test_domain2 site2
  prepare_domain $test_domain3 site2
}

function execute_suite() {
  test_role_idempotence

  test_nginx_is_running

  # Tests on test domain 1.
  test_site_is_protected "http://$test_domain1"

  test_site_is_up_with_credentials "http://$test_domain1" "This is the test site number 2." "test" "test"

  # Connections from 127.0.0.1 shoud have access granted.
  test_site_is_up_from_localhost "http://$test_domain1" "This is the test site number 2."



  # Tests on test domain 2.
  test_site_is_protected "http://$test_domain2"

  # Public folder is accesible.
  test_site_is_up "http://$test_domain2/public/" "This is the public folder of test site number 2."



  # Tests on test domain 3.
  test_site_is_forbidden "http://$test_domain3"

  # Public folder is accesible.
  test_site_is_up "http://$test_domain3/public/" "This is the public folder of test site number 2."

}
