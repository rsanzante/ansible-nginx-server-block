# Ansible Role: Nginx Server Block
----------------------------------

This role configures a single site using server blocks (virtual hosts using
Apache jargon). Can be used

Work in progress, alpha quality, but usable. Only tested with Ansible 2.4, but
it might work with other Ansible releases.

It may work with other distros, just make sure you configure properly, see
"Non Debian distros" section. In particular, it probably works with Alpine
Linux, but not tested yet.

A working Nginx should be configured, this role doesn't install it or configure
the http block level.

**Features**

  - Multiple listen configuration but allows simple common configuration.
  - Multiple location configurations.
  - Server restrictions and restrictions per location.
  - Fine-grained configuration for site.
  - SSL configuration (given cert and key files are available).
  - HTTP2.
  - Simple boolean variables can enable features on site (block .ht*, block
    source code files, block hidden directories, mask forbidden with 404, etc).


**Non Debian distros**

By default role is confugured for Debian like distros that use
sites-available/sites-enabled directories. For other distros, like CentOS, you
have to set the following variables:

    nsb_nginx_sites_available_path: conf.d
    nsb_nginx_sites_enabled_path: conf.d
    nsb_distro_allows_disabling_sites: no

The final configuration depends on your Nginx configuration.

If `nsb_distro_allows_disabling_sites` is yes, role deploys conf file in
`nsb_nginx_sites_available_path`, and then makes a symlink from
`nsb_nginx_sites_enabled_path` to conf file.

If `nsb_distro_allows_disabling_sites` is no, role deploys conf file in
`nsb_nginx_sites_enabled_path`, without making any symlink.


**Restriction**

A restriction block can be assigned to the server or to any location.

Restrictions covers:
  - Basic auth setup (with an existing htpassw file).
  - Allow/disallow clauses.
  - Change satisfy default value to 'any'.

See https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/.

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
      satisfy_any: yes
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

You can try for example this role to install Nginx: https://galaxy.ansible.com/HanXHX/nginx/
Or this one: https://galaxy.ansible.com/jdauphant/nginx/


## Role Variables
-----------------

#### Mandatory variables
------------------------

- nsb_domains: List of domains for this server block. At least one domain must
  be present. The first domain will be considered the main domain for this
  server block. Redirected domains will point to this main domain. Also,
  it's used for generated identifiers and names, like the main configuration
  file.

#### Mandatory when SSL is enabled
----------------------------------

- nsb_ssl_certificate_file: Path to certificate file.

- nsb_ssl_certificate_key_file: Path to certificate key file.


#### Optional/fine configuration variables (along with default value)
---------------------------------------------------------------------

- nsb_docroot_path:

  Path to docroot. If not set means that this server block probably will be
  a redirection, proxy or something similar.

- nsb_locations: []

  List of server locations. Each location have the following
  properties:

  - match: Location's  match clause. Mandatory.
    Ex: `/`, `/status`, `^~ /images/`, `~* \.(gif|jpg|jpeg)$`

  - body: Location's body, code inside the `{` and `}`. Mandatory.

  - restriction: Restriction block attached to this location. See
  **Restriction** section. This property is optional.

- nsb_server_block_enabled: yes

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

- nsb_use_access_log_file_for_site: yes

  Whether to use an access log file for this site or not.

- nsb_use_error_log_file_for_site: yes

  Whether to use an error log file for this site or not.

- nsb_log_dir_path: /var/log/nginx

  Directory where to put the log files.

- nsb_log_format_access: combined

  Log format used for access log.

- nsb_log_error_level: error

  Log level for error log.

- nsb_restriction: none

  Server context restriction block. See **Restriction** section.

- nsb_server_additional_conf: null

  Additional server block configuration. Use multiline syntax if more than one
  line is needed.


#### Variables to enable certain features using location blocks (along with default value)
------------------------------------------------------------------------------------------

- nsb_feature_ignore_ht_files: yes

  Add a location to ignore Apache's .ht* files.

- nsb_feature_ht_files_mask_404: yes

  Mask accesses to .ht* files as Paget Not Found 404 error.

- nsb_feature_dont_log_favicon: yes

  Do not log accesses to favicon.ico.

- nsb_feature_dont_log_robots_txt: yes

  Do not log accesses to robots.txt.

- nsb_feature_allow_well_known_rfc_5785: yes

  Allow access to .well-known directory as stated by RFC 5785.

- nsb_feature_block_hidden_dirs: yes

  Block access to directories that start with a period. This overlaps somewhat
  with the block Apache's .ht files snippet, but it's not harmful if both are
  enabled. You may want both enabled if you want to mask accessed .ht files as
  404.

- nsb_feature_block_php_source_and_related_files: yes

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
- nsb_distro_allows_disabling_sites: yes


Dependencies
------------

No direct dependencies but as said above Nginx must be installed.


Example Playbook
----------------


Simplest block server with just one simple location.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains:
             - example.com
           nsb_docroot_path: "/var/vhosts/example.com"
           nsb_https_enabled: no
           nsb_locations:
             - match: "/"
               body: |
                 index  index.html index.htm;


Block server with more options, SSL and restriction applied.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains:
             - example.com
             - www.example.com
           nsb_docroot_path: "/var/vhosts/example.com"
           nsb_https_enabled: yes
           nsb_ssl_certificate_file: /var/ssl/certs/example.com/fullchain.pem
           nsb_ssl_certificate_key_file: /var/ssl/certs/example.com/privatekey.pem
           nsb_restriction:
             satisfy_any: yes
             deny_allow_list:
               - deny 192.168.10.2
               - allow 192.168.10.1/24
               - allow 127.0.0.1
               - deny all
             basic_auth_enabled: yes
             basic_auth_name: 'Restricted area'
             basic_auth_passwd_filepath: '/etc/htpasswd/example.com/htpasswd'
           nsb_locations:
             - match: "/"
               body: |
                 root   /var/www/html;
                 index  index.html index.htm;


Block server with a simple redirection to another domain.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains:
             - example-old.com
           nsb_server_additional_conf: "return 301 https://example-new.com$request_uri;"
           nsb_force_https: no


Block server that acts as a proxy cache. Note that web_backend proxy must be
defined in the Nginx config elsewhere.

    - hosts: servers
      roles:
         - role: metadrop.nginx_server_block
           nsb_domains:
             - example.com
             - www.example.com
           nsb_docroot_path: "/var/vhosts/example.com"
           nsb_https_enabled: yes
           nsb_ssl_certificate_file: /var/ssl/certs/example.com/fullchain.pem
           nsb_ssl_certificate_key_file: /var/ssl/certs/example.com/privatekey.pem
        nsb_server_additional_conf: |
          # Enable proxy cache.
          proxy_cache general_cache;

          # Add header to report cache misses and hits.
          add_header X-Proxy-Cache $upstream_cache_status;
        nsb_locations:
          - match: "/"
            body: "try_files $uri @proxy;"
          - match: "@proxy"
            body: |
              limit_req zone=flood_protection burst=50 nodelay;
              proxy_pass http://web_backend;
              proxy_set_header  Host $host;
              proxy_set_header  X-Real-IP $remote_addr;
              proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header  X-Forwarded-By    $server_addr:$server_port;
              proxy_set_header  X-Local-Proxy     $scheme;
              proxy_set_header  X-Forwarded-Proto $scheme;

              proxy_pass_header Set-Cookie;
              proxy_pass_header Cookie;
              proxy_pass_header X-Accel-Expires;
              proxy_pass_header X-Accel-Redirect;
              proxy_pass_header X-This-Proto;



License
-------

GPL 3.0

Author Information
------------------

Ricardo Sanz ricardo@metadrop.net
