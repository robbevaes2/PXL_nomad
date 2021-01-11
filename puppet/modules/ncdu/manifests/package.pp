#
#
#
class ncdu::package {
  package {
    'epel-release':
      ensure => installed;
  }
  ->
  package {
    $ncdu::package_name:
      ensure => installed;
  }
}
