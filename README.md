# Ansible Role: Nginx Server Block
----------------------------------

This role configures a single site using server blocks (virtual hosts using
Apache jargon).

Work in progress, alpha quality.

**Features**

  - Multiple listen configuration but allows simple common configuration.
  - Multiple location configurations.
  - Server restrictions and restrictions per location.
  - Fine-grained configuration for site.
  - SSL configuration (given cert and key files are available).
  - HTTP2.
  - Simple boolean variables can enable features on site (block .ht*, block
    source code files, block hidden directories, mask forbidden with 404, etc).
  - ...


**Restriction**

A restriction block can be assigned to the server or to any location.

Restrictions covers:
  - Basic auth setup (with an existing htpassw file).
  - Allow/disallow clauses.
  - Change satisfy default value to 'any'.

Restriction block properties:

- satisfy_any: yes

  If yes, a `satisfy any;` clause is added.

- deny_allow_list: []

  List of allow/deny clauses.

- basic_auth_off: no

  Disables the basic auth for this block. Not valid for server context, only for
  location contexts. Used when there's a basic auth defined at server context
  and you want to disable in a certain location. If `basic_auth_enabled` is
  `yes` an error is triggered.

- basic_auth_enabled: no

  Enable basic auth.

- basic_auth_name: null

  Basic auth name. Mandatory when basic auth is enabled.

- basic_auth_passwd_filepath: null

  htpasswd file with valid users. Mandatory when basic auth is enabled.

Restriction block example:

    restriction:
      satisfy: yes
      deny_allow_list:
        - deny 192.168.1.2
        - allow 192.168.1.1/24
        - allow 127.0.0.1
        - deny all
      basic_auth_enabled: yes
      basic_auth_name: 'Restricted area'
      basic_auth_passwd_filepath: '/etc/htpasswd/file'



## Requirements
---------------

This role doesn't deal with Nginx installation or general configuration so Nginx
must be installed in the system prior to using this role.


## Role Variables
-----------------

#### Mandatory variables
------------------------

- nsb_domains: List of domains for this server block. At least one domain must
  be delvared. The first domain will be considered the main domain for this
  server block. Redirected domains will point to this main domain. Also,
  it's used for generated identifiers and names, like the main configuration file.

#### Mandatory when SSL is enabled
----------------------------------

- nsb_ssl_certificate_file: Path to certificate file.

- nsb_ssl_certificate_key_file: Path to certificate key file.


#### Optional/fine configuration variables (along with default value)
---------------------------------------------------------------------

- nbs_docroot_path:

  Path to docroot. If not set means that this server block probably will be
  a redirection, proxy or something similar.

- nbs_locations: []

  List of server locations. Each location have the following
  properties:

  - match: Location's  match clause. Mandatory.
    Ex: `/`, `/status`, `^~ /images/`, `~* \.(gif|jpg|jpeg)$`

  - body: Location's body, code inside the `{` and `}`. Mandatory.

  - restriction: Restriction block attached to this location. See
  **Restriction** section. This property is optional.

- nbs_server_block_enabled: yes

  Enables configured server block. If set to no, configuration is not loaded by
  Nginx. This disables the server block.

- nsb_ipv4_interface: '*'

  IPv4 interface to listen to for HTTP and HTTPS.

- nsb_ipv6_interface: '*'

  IPv6 interface to listen to for HTTP and HTTPS.

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

- nbs_restriction: none

  Server context restriction block. See **Restriction** section.

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

- nbs_feature_allow_well_known_rfc_5785: yes

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


Simplest block server with just one simple location.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains: "mydomain.com"
           nbs_docroot_path: "/var/vhosts/mydomain.com"
           nbs_locations:
             - match: "/"
               body: |
                 root   /var/www/html;
                 index  index.html index.htm;


Block server with more options, SSL and restriction applied.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains: "mydomain.com www.mydomain.com"
           nbs_docroot_path: "/var/vhosts/mydomain.com"
           nbs_https_enabled: yes
           nsb_ssl_certificate_file: /var/ssl/certs/mydomain.com/fullchain.pem
           nsb_ssl_certificate_key_file: /var/ssl/certs/mydomain.com/privatekey.pem
           nbs_restriction:
             satisfy: yes
             deny_allow_list:
               - deny 192.168.10.2
               - allow 192.168.10.1/24
               - allow 127.0.0.1
               - deny all
             basic_auth_enabled: yes
             basic_auth_name: 'Restricted area'
             basic_auth_passwd_filepath: '/etc/htpasswd/mydomain.com/htpasswd'
           nbs_locations:
             - match: "/"
               body: |
                 root   /var/www/html;
                 index  index.html index.htm;


License
-------

GPL 3.0

Author Information
------------------

Ricardo Sanz ricardo@metadrop.net
