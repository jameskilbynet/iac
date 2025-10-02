# RouterOS Configuration Template for VMware VCF Environment
# This file can be imported into MikroTik RouterOS using:
# /import file-name=vcf-template.rsc
#
# Before importing, customize the variables below to match your environment
# You can also use this as a reference for manual configuration

# System Configuration
/system identity
set name="vcf-switch-01"

/system clock
set time-zone-name=America/New_York

/system ntp client
set enabled=yes server-dns-names=pool.ntp.org

# DNS Configuration
/ip dns
set servers=8.8.8.8,8.8.4.4

# Security Configuration - Disable unnecessary services
/ip service
set telnet disabled=yes
set ftp disabled=yes
set api disabled=no port=8728
set api-ssl disabled=no port=8729
set www disabled=yes
set www-ssl disabled=no port=443
set ssh disabled=no port=22

# Bridge Configuration for VCF
/interface bridge
add name=br-vcf protocol-mode=rstp vlan-filtering=yes comment="VCF Main Bridge"

# Add trunk ports to bridge (customize port numbers as needed)
/interface bridge port
add bridge=br-vcf interface=ether2 comment="Trunk Port"
add bridge=br-vcf interface=ether3 comment="Trunk Port"
add bridge=br-vcf interface=ether4 comment="Trunk Port"
add bridge=br-vcf interface=ether5 comment="Trunk Port"
add bridge=br-vcf interface=ether6 comment="Trunk Port"
add bridge=br-vcf interface=ether7 comment="Trunk Port"
add bridge=br-vcf interface=ether8 comment="Trunk Port"

# Add uplink port to bridge
add bridge=br-vcf interface=ether24 comment="Uplink Port"

# VLAN Interfaces for VCF
/interface vlan
add interface=br-vcf name=vlan100 vlan-id=100 comment="Management VLAN"
add interface=br-vcf name=vlan101 vlan-id=101 comment="vMotion VLAN"
add interface=br-vcf name=vlan102 vlan-id=102 comment="vSAN VLAN"
add interface=br-vcf name=vlan103 vlan-id=103 comment="NSX TEP VLAN"
add interface=br-vcf name=vlan104 vlan-id=104 comment="NSX Edge TEP VLAN"
add interface=br-vcf name=vlan105 vlan-id=105 comment="VM Network VLAN"
add interface=br-vcf name=vlan106 vlan-id=106 comment="NFS Storage VLAN"

# Bridge VLAN Configuration
/interface bridge vlan
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=100 comment="Management VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=101 comment="vMotion VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=102 comment="vSAN VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=103 comment="NSX TEP VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=104 comment="NSX Edge TEP VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=105 comment="VM Network VLAN"
add bridge=br-vcf tagged=ether24 untagged="" vlan-ids=106 comment="NFS Storage VLAN"

# IP Addresses for VLAN interfaces (customize as needed)
/ip address
add address=192.168.100.1/24 interface=vlan100 comment="Management Gateway"
add address=192.168.101.1/24 interface=vlan101 comment="vMotion Gateway"
add address=192.168.102.1/24 interface=vlan102 comment="vSAN Gateway"
add address=192.168.103.1/24 interface=vlan103 comment="NSX TEP Gateway"
add address=192.168.104.1/24 interface=vlan104 comment="NSX Edge TEP Gateway"
add address=192.168.105.1/24 interface=vlan105 comment="VM Network Gateway"
add address=192.168.106.1/24 interface=vlan106 comment="NFS Storage Gateway"

# Management interface IP (customize interface name and IP)
add address=192.168.100.10/24 interface=ether1 comment="Management IP"

# Default route (customize gateway)
/ip route
add dst-address=0.0.0.0/0 gateway=192.168.100.1 comment="Default Route"

# IP forwarding
/ip settings
set ip-forward=yes

# DHCP Configuration for VM Network (optional)
/ip pool
add name=dhcp-vm-pool ranges=192.168.105.100-192.168.105.200

/ip dhcp-server network
add address=192.168.105.0/24 dns-server=8.8.8.8 gateway=192.168.105.1

/ip dhcp-server
add address-pool=dhcp-vm-pool interface=vlan105 name=dhcp-vm disabled=no

# Access Port Configuration Examples
# Configure specific ports as access ports for management VLAN
/interface bridge port
set [find interface=ether9] pvid=100
set [find interface=ether10] pvid=100

# Add access ports to VLAN as untagged
/interface bridge vlan
set [find vlan-ids=100] untagged=ether9,ether10

# Firewall Rules for VCF Traffic (basic examples)
/ip firewall filter
add action=accept chain=input connection-state=established,related comment="Allow established connections"
add action=accept chain=input protocol=icmp comment="Allow ICMP"
add action=accept chain=input in-interface=vlan100 protocol=tcp dst-port=22 comment="Allow SSH from Management VLAN"
add action=accept chain=input in-interface=vlan100 protocol=tcp dst-port=443 comment="Allow HTTPS from Management VLAN"
add action=accept chain=input src-address=192.168.100.0/24 comment="Allow Management Network"

# Drop everything else from WAN
add action=drop chain=input in-interface=ether24 comment="Drop from WAN"

# Inter-VLAN routing rules (customize based on security requirements)
add action=accept chain=forward connection-state=established,related comment="Allow established connections"
add action=accept chain=forward src-address=192.168.100.0/24 comment="Allow from Management"
add action=accept chain=forward src-address=192.168.101.0/24 dst-address=192.168.102.0/24 comment="vMotion to vSAN"
add action=accept chain=forward src-address=192.168.102.0/24 dst-address=192.168.101.0/24 comment="vSAN to vMotion"
add action=accept chain=forward src-address=192.168.103.0/24 dst-address=192.168.104.0/24 comment="TEP to Edge TEP"
add action=accept chain=forward src-address=192.168.104.0/24 dst-address=192.168.103.0/24 comment="Edge TEP to TEP"

# SNMP Configuration (uncomment and customize if needed)
# /snmp
# set contact=admin enabled=yes location="VCF Datacenter"
# 
# /snmp community
# set [find default=yes] name=vcf-readonly

# QoS Configuration for VCF Traffic (optional)
/queue type
add kind=pfifo name=vmotion-queue pfifo-limit=50

/queue simple
add name=vmotion-qos target=vlan101 max-limit=1G/1G priority=2/2 comment="vMotion QoS"
add name=vsan-qos target=vlan102 max-limit=10G/10G priority=1/1 comment="vSAN QoS"

# Logging Configuration
/system logging
add action=remote disabled=no prefix="" topics=info
add action=memory disabled=no prefix="" topics=warning,error,critical

# System Notes and Comments
/system note
set note="VMware VCF Switch Configuration - $(date +%Y-%m-%d)"
set show-at-login=yes

# End of configuration