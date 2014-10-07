## Class: rjil::openstack::glance
class rjil::glance (
  $ceph_mon_key = undef,
  $backend = 'file',
  $rbd_user = 'glance',
  $ceph_keyring_file_owner = 'glance',
  $ceph_keyring_path = '/etc/ceph/keyring.ceph.client.glance',
  $ceph_keyring_cap = 'mon "allow r" osd "allow class-read object_prefix rbd_children, allow rwx pool=images"'
) {

  ## Add tests for glance api and registry
  include rjil::test::glance

  rjil::profile { 'glance': }

  ## setup glance api
  include ::glance::api

  ## Setup glance registry
  include ::glance::registry

  if($backend == 'swift') {
    ## Swift backend
    include ::glance::backend::swift
  } elsif($backend == 'file') {
    # File storage backend
    include ::glance::backend::file
  } elsif($backend == 'rbd') {
    if ! defined(Class['rjil::ceph']) {
      fail("Class['rjil::ceph'] is not defined")
    }
    # Rbd backend
    Class['rjil::ceph'] ->  Class['::glance::backend::rbd']

    if ! $ceph_mon_key {
      fail("Parameter ceph_mon_key is not defined")
    }
    ::ceph::auth {'glance_client':
      mon_key      => $ceph_mon_key,
      client       => $rbd_user,
      file_owner   => $ceph_keyring_file_owner,
      keyring_path => $ceph_keyring_path,
      cap          => $ceph_keyring_cap,
    }

    ::ceph::conf::clients {'glance':
      keyring => $ceph_keyring_path,
    }

    include ::glance::backend::rbd
  } elsif($backend == 'cinder') {
    # Cinder backend
    include ::glance::backend::cinder
  } else {
    fail("Unsupported backend ${backend}")
  }

  rjil::jiocloud::consul::service { "glance":
    tags          => ['real'],
    port          => $::glance::api::bind_port,
    check_command => "/usr/lib/nagios/plugins/check_http -I ${::glance::api::bind_host} -p ${::glance::api::bind_port}"
  }
}
