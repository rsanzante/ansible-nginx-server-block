# Ansible Role: Nginx Server Block
----------------------------------

This role configures a single site using server blocks (virtual hosts using
Apache jargon).

Work in progress, alpha quality.

**Features**

  - Multiple listen configuration but allows simple common configuration.
  - Múltiple location configurations.
  - Fine-grained configuration for site.
  - SSL configuration (given cert and key files are available).
  - Simple boolean variables can enable features on site (block .ht*, block
    source code files, block hidden directories, mask forbidden with 404, etc).
  - ...


## Requirements
---------------

This role doesn't deal with Nginx installation or general configuration so Nginx
must be installed in the system prior to use the role.


## Role Variables
--------------

#### Mandatory variables
------------------------


- nsb_main_domain: Main domain for this server block. Redirected domains will
  point to this domain. Also, it's used for generated identifiers and names,
  like the main configuration file.

- nbs_docroot_path: Path to docroot.

#### Mandatory when SSL is enabled
----------------------------------

- nsb_ssl_certificate_file: Path to certificate file.

- nsb_ssl_certificate_key_file: Path to certificate key file.

#### Optional/fine configuration variables (along with default value)
---------------------------------------------------------------------

- nbs_server_block_enabled: yes

  Enables configured server block. If set to no, configuration is not loaded by
  Nginx.

- nsb_secondary_domains: []

  List of seconday domains for this server block.

- nsb_ipv4_interface: '*'

  IP4 interface to listen to for HTTP and HTTPS.

- nsb_ipv6_interface: '*'

  IP4 interface to listen to for HTTP and HTTPS.

- nsb_listen_port: 80

  Nginx will listen to this port for incoming HTTP
  connections.

- nsb_ssl_listen_port: 443

  Nginx will listen to this port for incoming HTTPS
  connections.

- nsb_additional_listen_configuration: []

  Complex listen configuration can be added to this variable if needed. See
  defaults/main.yml to get the details.

- nbs_use_access_log_file_for_site: yes

  Whether to use an access log file for this site or not.

- nbs_use_error_log_file_for_site: yes

  Whether to use an error log file for this site or not.

- nsb_log_dir_path: /var/log/nginx

  Directory where to put the log files.

- nbs_log_format_access: combined

  Log format used for access log.

- nbs_log_error_level: error

  Log level for error log.

- nbs_server_additional_conf: null

  Additional server block configuration. Use multiline syntax if more than one
  line is needed.


#### Variables to enable certain features using location blocks (along with default value)
------------------------------------------------------------------------------------------

- nbs_feature_ignore_ht_files: yes

  Add a location to ignore Apache's .ht* files.

- nbs_feature_ht_files_mask_404: yes

  Mask accesses to .ht* files as Paget Not Found 404 error.

- nbs_feature_dont_log_favicon: yes

  Do not log accesses to favicon.ico.

- nbs_feature_dont_log_robots_txt: yes

  Do not log accesses to robots.txt.

- nbs_feature_allow_well_known_rc_5785: yes

  Allow access to .well-known directory as stated by RFC 5785.

- nbs_feature_block_hidden_dirs: yes

  Block access to directories that start with a period. This overlaps somewhat
  with the block Apache's .ht* files snippet, but it's not harmful if both are
  enabled. You may want both enabled if you want to mask accessed .ht* files as
  404.

- nbs_feature_block_php_source_and_related_files: yes

  Block access to many confidential files (based on Drupal's list) like php,
  sql, composer.json, bak, yml, etc.



#### More optional/fine configuration variables (along with default value)
--------------------------------------------------------------------------

- nsb_ipv4_interface: '*'

  Interface for IPv4 connections. If '*' all interfaces are used. If None no
  IPv4 interface is used.

- nsb_ipv6_interface: '*'

  Interface for IPv6 connections. If '*' all interfaces are used. If None no
  IPv6 interface is used.

- nsb_conf_file_owner: root

  User to own configuration files.

- nsb_conf_file_group: www-data

  Configuration files assigned group.

#### Other variables
--------------------

Optional Nginx configuration variables. Those variables DO NOT configure Nginx
but report the Nginx configuration to this role.

- nsb_nginx_conf_dir: /etc/nginx
- nsb_nginx_sites_available_path: sites-available
- nsb_nginx_sites_enabled_path: sites-enabled




Dependencies
------------

No direct dependencies but as said above Nginx must be installed.


Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

GPL 3.0

Author Information
------------------

Ricardo Sanz ricardo@metadrop.net
