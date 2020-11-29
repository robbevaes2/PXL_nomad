<h1> Groep 2 - Linux PE2 Documentatie <h1>
<h2> Installatie en Configruatie <h2>

Met het volgende commando worden er 1 server en 2 client Virtuele machine's opgestart
```
$ vagrant up
```

# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vbguest.auto_update = false
  config.vm.box = "centos/7"

  config.vm.define :server do |server|
    server.vm.hostname = "server"
    server.vm.network "private_network", ip: "192.168.1.2", type: "static"
    server.vm.network "forwarded_port", guest: 4646, host: 4646, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true, host_ip: "127.0.0.1"
	
	server.vm.provision "ansible" do |ansible|
      ansible.config_file = "ansible/ansible.cfg"
      ansible.playbook = "ansible/plays/initial.yml"
      ansible.groups = {
        "servers" => ["server"]
      }
      ansible.host_vars = {
#        "server" => {"bind_address" => "\"192.168.1.2\""}
      }
      ansible.verbose = '-vvv'
    

 end
end

  config.vm.define :client1 do |client1|
    client1.vm.hostname = "client1"
	client1.vm.network "private_network", ip:"192.168.1.3", type: "static"
	
	client1.vm.provision "ansible" do |ansible|
      ansible.config_file = "ansible/ansible.cfg"
      ansible.playbook = "ansible/plays/initial.yml"
      ansible.groups = {
		"clients" => ["client1"],
#    "clients:vars" => {"retry_join" => "retry_join = [\"192.168.1.2\"]"} 
      }
      ansible.host_vars = {
#        "client1" => {"bind_address" => "\"192.168.1.3\""}
      }
      ansible.verbose = '-vvv'

 end
  end
  config.vm.define :client2 do |client2|
    client2.vm.hostname = "client2"
	client2.vm.network "private_network", ip:"192.168.1.4", type: "static"
	
	client2.vm.provision "ansible" do |ansible|
      ansible.config_file = "ansible/ansible.cfg"
      ansible.playbook = "ansible/plays/initial.yml"
      ansible.groups = {
		"clients" => ["client2"],
#    "clients:vars" => {"retry_join" => "retry_join = [\"192.168.1.2\"]"} 
      }
      ansible.host_vars = {
#        "client2" => {"bind_address" => "\"192.168.1.4\""}
      }
      ansible.verbose = '-vvv'

 end
  end
end
```

In de Vagrantfile gebeurd het volgende:

- Aan elke virtuele machine wordt een hostname toegekend.
- Aan elke machine wordt een statisch ip toegekend.
- De interface van Nomad wordt opgestart.
- De interface van Consul wordt opgestart.
- De VM wordt aan een groep toegekend.

De volgende rollen worden per Virtuele Machine geinstaleerd:
- Nomad
- Consul
- Docker

```
---
- name: playbook for server vm
  hosts: servers
  become: yes

  roles:
   - role: software/nomad
   - role: software/consul
   - role: software/docker

- name: playbook for clients
  hosts: clients
  become: yes
  
  roles:
   - role: software/nomad
   - role: software/consul
   - role: software/docker
```

We maken gebruik van variabelen op groepniveau en op default niveau. De variabelen op groepniveau hebben voorang op die van default.

Groups:
	Clients:
```
---
consul__retry_join: "retry_join = [\"192.168.1.2\"]"
consul__serverstatus: "#server = false"
consul__bootstrapstatus: "#bootstrap_expect=1"
consul__bind_address: "bind_addr = \"{{ansible_eth1.ipv4.address}}\""
nomad__datadir: "/opt/nomad/client"
nomad__serverip: "[\"192.168.1.2:4647\"]"
nomad__bind_address: "{{ansible_eth1.ipv4.address}}"
```

Groups:
	Servers:
```
nomad__datadir: "/opt/nomad/server"
nomad__bind_address: "{{ansible_eth1.ipv4.address}}"
nomad__serverenabledisable: "true"
consul__bind_address: "bind_addr = \"{{ansible_eth1.ipv4.address}}\""
```

Consul:
	Defaults:
```
---
consul__bind_address: ""
consul__retry_join: "#retry_join"
consul__serverstatus: "server = true"
consul__bootstrapstatus: "bootstrap_expect=1"
```

Consul:
	Template:
```
# Full configuration options can be found at https://www.consul.io/docs/agent/options.html

# datacenter
# This flag controls the datacenter in which the agent is running. If not provided,
# it defaults to "dc1". Consul has first-class support for multiple datacenters, but 
# it relies on proper configuration. Nodes in the same datacenter should be on a 
# single LAN.
#datacenter = "my-dc-1"

# data_dir
# This flag provides a data directory for the agent to store state. This is required
# for all agents. The directory should be durable across reboots. This is especially
# critical for agents that are running in server mode as they must be able to persist
# cluster state. Additionally, the directory must support the use of filesystem
# locking, meaning some types of mounted folders (e.g. VirtualBox shared folders) may
# not be suitable.
data_dir = "/opt/consul"

# client_addr
# The address to which Consul will bind client interfaces, including the HTTP and DNS
# servers. By default, this is "127.0.0.1", allowing only loopback connections. In
# Consul 1.0 and later this can be set to a space-separated list of addresses to bind
# to, or a go-sockaddr template that can potentially resolve to multiple addresses.
client_addr = "0.0.0.0"

# ui
# Enables the built-in web UI server and the required HTTP routes. This eliminates
# the need to maintain the Consul web UI files separately from the binary.
ui = true

# server
# This flag is used to control if an agent is in server or client mode. When provided,
# an agent will act as a Consul server. Each Consul cluster must have at least one
# server and ideally no more than 5 per datacenter. All servers participate in the Raft
# consensus algorithm to ensure that transactions occur in a consistent, linearizable
# manner. Transactions modify cluster state, which is maintained on all server nodes to
# ensure availability in the case of node failure. Server nodes also participate in a
# WAN gossip pool with server nodes in other datacenters. Servers act as gateways to
# other datacenters and forward traffic as appropriate.
{{consul__serverstatus}}

# bootstrap_expect
# This flag provides the number of expected servers in the datacenter. Either this value
# should not be provided or the value must agree with other servers in the cluster. When
# provided, Consul waits until the specified number of servers are available and then
# bootstraps the cluster. This allows an initial leader to be elected automatically.
# This cannot be used in conjunction with the legacy -bootstrap flag. This flag requires
# -server mode.
{{consul__bootstrapstatus}}

# encrypt
# Specifies the secret key to use for encryption of Consul network traffic. This key must
# be 32-bytes that are Base64-encoded. The easiest way to create an encryption key is to
# use consul keygen. All nodes within a cluster must share the same encryption key to
# communicate. The provided key is automatically persisted to the data directory and loaded
# automatically whenever the agent is restarted. This means that to encrypt Consul's gossip
# protocol, this option only needs to be provided once on each agent's initial startup
# sequence. If it is provided after Consul has been initialized with an encryption key,
# then the provided key is ignored and a warning will be displayed.
#encrypt = "..."

# retry_join
# Similar to -join but allows retrying a join until it is successful. Once it joins 
# successfully to a member in a list of members it will never attempt to join again.
# Agents will then solely maintain their membership via gossip. This is useful for
# cases where you know the address will eventually be available. This option can be
# specified multiple times to specify multiple agents to join. The value can contain
# IPv4, IPv6, or DNS addresses. In Consul 1.1.0 and later this can be set to a go-sockaddr
# template. If Consul is running on the non-default Serf LAN port, this must be specified
# as well. IPv6 must use the "bracketed" syntax. If multiple values are given, they are
# tried and retried in the order listed until the first succeeds. Here are some examples:
#retry_join = ["consul.domain.internal"]
{{consul__retry_join}}
#retry_join = ["[::1]:8301"]
#retry_join = ["consul.domain.internal", "10.0.4.67"]
# Cloud Auto-join examples:
# More details - https://www.consul.io/docs/agent/cloud-auto-join
#retry_join = ["provider=aws tag_key=... tag_value=..."]
#retry_join = ["provider=azure tag_name=... tag_value=... tenant_id=... client_id=... subscription_id=... secret_access_key=..."]
#retry_join = ["provider=gce project_name=... tag_value=..."]
{{consul__bind_address}}
```

Nomad:
	Default:
```
---
nomad__bind_address: ""
nomad__datadir: ""
nomad__serverip: "[\"127.0.0.1:4646\"]"
nomad__serverenabledisable: "false"
```

Nomad:
	Template:
```
# Full configuration options can be found at https://www.nomadproject.io/docs/configuration

data_dir = "{{nomad__datadir}}"
log_level = "DEBUG"
bind_addr = "{{nomad__bind_address}}"

server {
  enabled = {{nomad__serverenabledisable}}
  bootstrap_expect = 1
}

client {
  enabled = true  
  servers = {{nomad__serverip}}
}
```

Volgende handlers en tasks worden uitgevoerd voor Consul, Nomad en Docker.

Consul:
	Handler:
```
---
- name: restart consul
  service:
    name: consul
    state: restarted
```

Consul:
	Task:
```
---  
- name: setup repo
  yum_repository:
    name: consul
    description: add consul repo
    baseurl: https://rpm.releases.hashicorp.com/RHEL/$releasever/$basearch/stable
    gpgkey: https://rpm.releases.hashicorp.com/gpg
    
- name: install consul
  yum:
    name: consul
    state: present

- name: change consul hcl
  template:
    src: consul.hcl.j2
    dest: /etc/consul.d/consul.hcl
  notify: restart consul
```

Nomad:
	Handler:
```
---
- name: restart nomad
  service:
    name: nomad
    state: restarted

- name: Create nomad datadir
  file:
    path: "{{nomad__datadir}}"
    state: directory
    mode: '0755'
```

Nomad:
	Task:
```
---
- name: setup repo
  yum_repository:
    name: nomad
    description: add nomad repo
    baseurl: https://rpm.releases.hashicorp.com/RHEL/$releasever/$basearch/stable
    gpgkey: https://rpm.releases.hashicorp.com/gpg
    
- name: install nomad
  yum:
    name: nomad
    state: present
  notify: Create nomad datadir

- name: replace hcl file nomad
  template:
    src: nomad.hcl.j2
    dest: /etc/nomad.d/nomad.hcl
  notify: restart nomad
```

Docker:
	Handler:
```
---
- name: restart docker
  service:
    name: docker
    state: restarted
```

Docker:
	Task:
```
---
- name: add docker-ce repository
  yum_repository:
    name: docker-ce
    description: add docker-ce repository
    baseurl: https://download.docker.com/linux/centos/$releasever/$basearch/stable
    gpgkey: https://download.docker.com/linux/centos/gpg
- name: install docker-ce
  yum:
    name: docker-ce
    state: present
  notify: restart docker
```


