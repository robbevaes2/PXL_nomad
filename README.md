# Groep 2 - Linux PE2 Documentatie 

Met het volgende commando worden er 1 server en 2 client Virtuele machines opgestart
```
$ vagrant up
```
Aan de hand van volgende vagrant file worden deze virtuele machines opgezet: 

```
# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "centos/7"
  config.vm.provider :virtualbox do |virtualbox, override|
    virtualbox.customize ["modifyvm", :id, "--memory", 2048]
  end

  config.vm.define :server do |server|
    server.vm.hostname = "server"
    server.vm.network "private_network", ip: "192.168.1.2", type: "static"
    server.vm.network "forwarded_port", guest: 4646, host: 4646, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 9090, host: 9090, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true, host_ip: "127.0.0.1"
    server.vm.network "forwarded_port", guest: 9093, host: 9093, auto_correct: true, host_ip: "127.0.0.1"
	
	server.vm.provision "ansible_local" do |ansible|
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
	
	client1.vm.provision "ansible_local" do |ansible|
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
	
	client2.vm.provision "ansible_local" do |ansible|
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
- Voor de server vm wordt er ook geport forward.
- De interface van Nomad wordt opgestart.
- De interface van Consul wordt opgestart.
- De VM wordt aan een groep toegekend.

De volgende rollen worden per Virtuele Machine geinstaleerd:
- Nomad
- Consul
- Docker
- node_exporter (voor het verkrijgen van metrics)
- prometheus

Nomad, consul en Docker zijn in PE2 aangehaald, deze gaan we hier niet opnieuw aanhalen. in de ```initial.yml``` file zijn wel aanpassingen gebeurd.
Voor de server en clients installeren we volgende rollen (initial.yml)
```
---
- name: playbook for server vm
  hosts: servers
  become: yes

  roles:
   - role: software/nomad
   - role: software/consul
   - role: software/docker
   - role: software/prometheus
   - role: software/node_exporter

- name: playbook for clients
  hosts: clients
  become: yes
  
  roles:
   - role: software/nomad
   - role: software/consul
   - role: software/docker
   - role: software/node_exporter
```

Er zijn dus 2 roles bijgekomen, namelijke prometheus en de node_exporter. 

node_exporter (handlers/main.yml)
```
  ---
- name: Started Node_exporter
  service:
    name: node_exporter
    state: started
```

node_exporter (tasks/main.yaml)
```
---
- name: Download node_exporter
  get_url:
    url: https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /home/vagrant
    mode: '0776'
    
- name: Extract node_exporter
  unarchive:
    src: /home/vagrant/node_exporter-1.0.1.linux-amd64.tar.gz
    dest: /home/vagrant

- name: Move node_exporter
  command: mv /home/vagrant/node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/

- name: Node_exporter .service file
  template: 
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service

- name: Start node_exporter
  service:
    name: node_exporter
    state: started
```

Voor de node_exporter hebben we volgende tempalte gebruikt.
node_exporter (templates/node_exporter.service)
```
[Unit]
Description=Node Exporter
After=network.target
 
[Service]
User=vagrant
Group=vagrant
Type=simple
ExecStart=/usr/local/bin/node_exporter
 
[Install]
WantedBy=multi-user.target
```

Voor Prometheus hebben we dan het volgende

prometheus (handers/main.yml)
```
---
- name: Start prometheus job
  shell: nomad job run -address=http://{{nomad__bind_address}}:4646 /opt/nomad/prometheus.hcl || exit 0

- name: Start grafana job
  shell: nomad job run -address=http://{{nomad__bind_address}}:4646 /opt/nomad/grafana.hcl || exit 0

- name: Start alertmanager job
  shell: nomad job run -address=http://{{nomad__bind_address}}:4646 /opt/nomad/alertmanager.hcl || exit 0

- name: Start extra_job job
  shell: nomad job run -address=http://{{nomad__bind_address}}:4646 /opt/nomad/extra_job.hcl || exit 0
```

prometheus (tasks/main.yaml)
```
---
- name: Create a directory for the prometheus yml file
  file:
    path: /opt/prometheus
    state: directory
    mode: '0755'

- name: create a directory for the alertmanager rules file
  file:
    path: /opt/alertmanager
    state: directory
    mode: '0755'

- name: Move alertmanager infrastructure rules template
  template:
    src: infrastructure.rules.j2
    dest: /opt/alertmanager/infrastructure.rules
  
- name: Move the prometheus.yml file over to the correct dest
  template: 
    src: prometheus.yml.j2
    dest: /opt/prometheus/prometheus.yml

- name: Use the prometheus template to create the job file
  template: 
    src: prometheus.hcl.j2
    dest: /opt/nomad/prometheus.hcl
  vars:
    job_name: prometheus
    job_image: prom/prometheus:latest
    job_port: 9090
  notify: Start prometheus job

- name: Use the grafana template to create the job file
  template: 
    src: jobs.hcl.j2
    dest: /opt/nomad/grafana.hcl
  vars:
    job_name: grafana
    job_image: grafana/grafana:latest
    job_port: 3000
  notify: Start grafana job

- name: Use the alertmanager template to create the job file
  template: 
    src: jobs.hcl.j2
    dest: /opt/nomad/alertmanager.hcl
  vars:
    job_name: alertmanager
    job_image: prom/alertmanager:latest
    job_port: 9093
  notify: Start alertmanager job

- name: Use the extra_job template to create the job file
  template: 
    src: extra_job.hcl.j2
    dest: /opt/nomad/extra_job.hcl
  notify: Start extra_job job

- name: Use the extra_job template with the rules
  template:
    src: rules.yml.j2
    dest: /opt/prometheus/rules.yml
  notify: Start extra_job job
```
Voor prometheus hebben we volgende templates gebruikt

prometheus (templates/jobs.hcl) Dit is de algemene HCL jobs (voor grafana en alertmanager)
```
job "{{job_name}}" {
    datacenters = ["dc1"] 
    type = "service"

    group "{{job_name}}" {
        count = 1
        network {
            port "{{job_name}}_port" {
            to = {{job_port}}
            static = {{job_port}}
            }
        }
      task "{{job_name}}" {
        driver = "docker"
        config {
            image = "{{job_image}}"
            ports = ["{{job_name}}_port"]
            logging {
                type = "journald"
                config {
                    tag = "{{job_name}}"
                }
            }
        }
        service {
            name = "{{job_name}}"
            tags = ["metrics"]
        }
      }
    }
}
```
prometheus (templates/prometheus.hcl) deze is voor prometheus
```
job "{{job_name}}" {
	datacenters = ["dc1"] 
	type = "service"

	group "{{job_name}}" {
		count = 1
		network {
			port "{{job_name}}_port" {
			to = {{job_port}}
			static = {{job_port}}
			}
		}
	  task "{{job_name}}" {
		driver = "docker"
		config {
			image = "{{job_image}}"
			ports = ["{{job_name}}_port"]
			logging {
				type = "journald"
				config {
					tag = "{{job_name}}"
				}
			}
        volumes = [
          "/opt/prometheus/:/etc/prometheus/"
        ]
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
          "--web.enable-admin-api"
        ]
		}
		service {
			name = "{{job_name}}"
		}
	  }
	}
}
```

prometheus (templates/prometheus.yml) voor de configuratie van prometheus
```
global:                                       
  scrape_interval:     5s                     
  evaluation_interval: 5s  

alerting:
  alertmanagers:
    - consul_sd_configs:
      - server: '192.168.1.2:8500'
        services: ['alertmanager']
    - relabel_configs: 
        - source_labels: [__address__]          
          action: replace                       
          regex: ([^:]+):.*                     
          replacement: $1:9093              
          target_label: __address__

rule_files:
 - rules.yml                   
                                              
scrape_configs:                               
                                              
  - job_name: 'nomad_metrics'                 
                                              
    consul_sd_configs:                        
    - server: '192.168.1.2:8500'             
      services: ['nomad-client', 'nomad']     
                                              
    relabel_configs:                          
    - source_labels: ['__meta_consul_tags']   
      regex: '(.*)http(.*)'                   
      action: keep                            
                                              
    scrape_interval: 5s                       
    metrics_path: /v1/metrics                 
    params:                                   
      format: ['prometheus']     
                   
  - job_name: 'node_exporter'                 
    consul_sd_configs:                        
      - server: '192.168.1.2:8500'           
        services: ['nomad-client']            
    relabel_configs:                          
      - source_labels: [__meta_consul_tags]   
        regex: '(.*)http(.*)'                 
        action: keep                          
      - source_labels: [__meta_consul_service]
        target_label: job                     
      - source_labels: [__address__]          
        action: replace                       
        regex: ([^:]+):.*                     
        replacement: $1:9100                  
        target_label: __address__ 

  - job_name: 'extra_job'
    consul_sd_configs:
      - server: '192.168.1.2:8500'
        services: ['extra-job']
    metrics_path: /metrics

  - job_name: 'alertmanager'
    consul_sd_configs:
      - server: '192.168.1.2:8500'
        services: ['alertmanager']
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job
      - source_labels: [__address__]          
        action: replace                       
        regex: ([^:]+):.*                     
        replacement: $1:9093              
        target_label: __address__

    scrape_interval: 5s
    metrics_path: /metrics
    params:
      format: ['prometheus']
```

prometheus (templates/extra_job.hcl) Dit is de extra job die we aanmaken voor de metrics te verkrijgen
```
job "extra-job" {
  datacenters = ["dc1"]

  group "extra-job" {
    task "server" {
      driver = "docker"
      config {
        image = "hashicorp/demo-prometheus-instrumentation:latest"
      }

      resources {
        cpu = 500
        memory = 256
        network {
          mbits = 10
          port  "http"{}
        }
      }

      service {
        name = "extra-job"
        port = "http"

        tags = [
          "testweb",
          "urlprefix-/extra_job strip=/extra-job",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
```

## Extra

prometheus (templates/rules.yml) hier worden de rules voor prometheus aangemaakt
```
groups:
  - name: Prometheus rules for target missing
    rules:
      - alert: PrometheusTargetMissing
        expr: up == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Prometheus target missing 
          description: A Prometheus target has disappeared. An exporter might be crashed.
  - name: prometheus alerts for job down
    rules:
      - alert: job down
        expr: absent(up{job="extra_job"})
        for: 10s
        labels:
          severity: critical
        annotations:
          description: "Our extra job is down."
```

## Verdelingen van de taken

We hebben de volledige opdracht samen gemaakt. We doen dit zodat we ook allebei alle elementen die aan bod komen begrijpen.




