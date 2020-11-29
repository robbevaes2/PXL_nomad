# puppet.pp
#
# example manifest for our puppet virtualbox vm
node 'puppet.lan' {

  include roles::puppet

}
