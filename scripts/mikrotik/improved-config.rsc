# Improved MikroTik RouterOS Configuration
# Based on analysis of extracted_192_168_3_1_20251001_184431.rsc
# Generated on: 2025-10-01
# Improvements: Security hardening, VLAN optimization, QoS, monitoring

#==============================================================================
# SECURITY HARDENING
#==============================================================================

# System Identity and Basic Settings
/system identity set name="100g-1-secured"

# Time and NTP Configuration
/system clock set time-zone-name=Europe/London
/system ntp client set enabled=yes server-dns-names=pool.ntp.org

# DNS Configuration (use secure DNS servers)
/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=no

# CRITICAL: Disable insecure services
/ip service set ftp disabled=yes
/ip service set telnet disabled=yes
/ip service set www disabled=yes
/ip service set dhcp disabled=yes
/ip service set btest disabled=yes
/ip service set discover disabled=yes

# Enable only secure services with custom ports
/ip service set ssh disabled=no port=2222  # Changed from default port 22
/ip service set www-ssl disabled=no port=8443  # Changed from default port 443
/ip service set winbox disabled=no port=8291
/ip service set api disabled=yes  # Disable non-SSL API
/ip service set api-ssl disabled=no port=8729
/ip service set snmp disabled=no port=161

# User Management - Create dedicated users and disable default admin
/user add name=netadmin group=full password=ChangeThisPassword! comment="Network Administrator"
/user add name=readonly group=read password=ReadOnlyPass! comment="Read-only monitoring user"
# TODO: Disable default admin user after testing: /user disable admin

#==============================================================================
# NETWORK ARCHITECTURE IMPROVEMENTS
#==============================================================================

# Improved Bridge Configuration with VLAN filtering
/interface bridge
remove [find name=bridge]
add name=br-main protocol-mode=rstp vlan-filtering=yes fast-forward=yes \
    comment="Main bridge with VLAN filtering enabled"

# STP Configuration for loop prevention
/interface bridge set br-main stp-forwarding-delay=4s stp-hello-time=2s \
    stp-max-age=6s stp-priority=0x8000

# Bridge Port Configuration with improved structure
# Uplink Port
/interface bridge port
add bridge=br-main interface=qsfp28-1-1 comment="UPLINK" edge=no point-to-point=auto

# Nutanix Cluster Ports (High-priority trunk ports)
add bridge=br-main interface=qsfp28-1-2 comment="uk-bhr-p-ntnx-1" edge=no
add bridge=br-main interface=qsfp28-1-3 comment="uk-bhr-p-ntnx-2" edge=no  
add bridge=br-main interface=qsfp28-3-1 comment="uk-bhr-p-ntnx-1-backup" edge=no
add bridge=br-main interface=qsfp28-3-2 comment="uk-bhr-p-ntnx-2-backup" edge=no
add bridge=br-main interface=qsfp28-3-3 comment="uk-bhr-p-ntnx-3" edge=no
add bridge=br-main interface=qsfp28-3-4 comment="uk-bhr-p-ntnx-3-backup" edge=no

# Storage Ports
add bridge=br-main interface=qsfp28-1-4 comment="StoreServ1" edge=no
add bridge=br-main interface=qsfp28-2-4 comment="Storeserv2" edge=no

# Compute/Workstation Ports
add bridge=br-main interface=qsfp28-2-2 comment="Z840-1" edge=no
add bridge=br-main interface=qsfp28-2-3 comment="Z840-2" edge=no
add bridge=br-main interface=qsfp28-4-1 comment="ESX-C" edge=no

# Unused ports (disabled for security)
add bridge=br-main interface=qsfp28-2-1 comment="Unused-disabled" edge=no disabled=yes
add bridge=br-main interface=qsfp28-4-2 comment="Unused-disabled" edge=no disabled=yes
add bridge=br-main interface=qsfp28-4-3 comment="Unused-disabled" edge=no disabled=yes
add bridge=br-main interface=qsfp28-4-4 comment="Unused-disabled" edge=no disabled=yes

#==============================================================================
# VLAN CONFIGURATION (Structured and Documented)
#==============================================================================

# VLAN Interfaces for management and routing
/interface vlan
add interface=br-main name=vlan1-default vlan-id=1 comment="Default VLAN"
add interface=br-main name=vlan3-management vlan-id=3 comment="Management Network"
add interface=br-main name=vlan4-infrastructure vlan-id=4 comment="Infrastructure Services"
add interface=br-main name=vlan20-workstations vlan-id=20 comment="Workstation Network"
add interface=br-main name=vlan38-vmotion vlan-id=38 comment="VMware vMotion"
add interface=br-main name=vlan39-vsan vlan-id=39 comment="VMware vSAN"
add interface=br-main name=vlan40-nsx-tep vlan-id=40 comment="NSX Tunnel Endpoints"
add interface=br-main name=vlan60-storage-mgmt vlan-id=60 comment="Storage Management"
add interface=br-main name=vlan61-storage-data vlan-id=61 comment="Storage Data"

# Bridge VLAN Configuration - Structured by VLAN ID
/interface bridge vlan

# VLAN 1 - Default (untagged on storage devices, tagged on trunks)
add bridge=br-main vlan-ids=1 \
    tagged=qsfp28-1-1,qsfp28-1-2,qsfp28-1-3,qsfp28-2-2,qsfp28-2-3,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4 \
    untagged=br-main,qsfp28-1-4,qsfp28-2-4

# VLAN 3 - Management Network (tagged on all active ports)
add bridge=br-main vlan-ids=3 \
    tagged=qsfp28-1-1,qsfp28-1-2,qsfp28-1-3,qsfp28-2-2,qsfp28-2-3,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4 \
    comment="Management Network"

# VLAN 4 - Infrastructure Services (ESXi management, uplink, compute nodes)
add bridge=br-main vlan-ids=4 \
    tagged=qsfp28-1-1,qsfp28-4-1,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-2-2,qsfp28-1-2,qsfp28-1-3,qsfp28-3-4,qsfp28-2-3 \
    comment="Infrastructure Services"

# VLAN 20 - Workstation Network
add bridge=br-main vlan-ids=20 \
    tagged=qsfp28-1-1,qsfp28-2-2,qsfp28-1-2,qsfp28-1-3,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4,qsfp28-2-3 \
    comment="Workstation Network"

# VLAN 38 - VMware vMotion (high-performance network)
add bridge=br-main vlan-ids=38 \
    tagged=qsfp28-4-1,qsfp28-1-1,qsfp28-2-2,qsfp28-1-2,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-1-3,qsfp28-3-4,qsfp28-2-3 \
    comment="VMware vMotion - High Priority"

# VLAN 39 - VMware vSAN (storage network)
add bridge=br-main vlan-ids=39 \
    tagged=qsfp28-2-2,qsfp28-1-1,qsfp28-1-2,qsfp28-1-3,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4,qsfp28-2-3 \
    comment="VMware vSAN - Storage Traffic"

# VLAN 40 - NSX Tunnel Endpoints
add bridge=br-main vlan-ids=40 \
    tagged=qsfp28-1-1,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-1-2,qsfp28-1-3,qsfp28-3-4,qsfp28-2-2,qsfp28-2-3 \
    comment="NSX Tunnel Endpoints"

# VLAN 60 - Storage Management
add bridge=br-main vlan-ids=60 \
    tagged=qsfp28-1-1,qsfp28-1-4,qsfp28-2-2,qsfp28-1-2,qsfp28-1-3,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4,qsfp28-2-3 \
    comment="Storage Management"

# VLAN 61 - Storage Data
add bridge=br-main vlan-ids=61 \
    tagged=qsfp28-1-1,qsfp28-1-2,qsfp28-1-3,qsfp28-2-4,qsfp28-3-1,qsfp28-3-2,qsfp28-3-3,qsfp28-3-4,qsfp28-2-2,qsfp28-2-3 \
    comment="Storage Data Network"

#==============================================================================
# IP ADDRESS CONFIGURATION
#==============================================================================

# Management IP on physical interface (keep existing)
/ip address add address=192.168.3.1/24 interface=ether1 comment="Physical Management"

# VLAN Gateway IPs
/ip address add address=192.168.1.1/24 interface=vlan1-default comment="Default VLAN Gateway"
/ip address add address=192.168.3.1/24 interface=vlan3-management comment="Management Gateway"
/ip address add address=192.168.4.1/24 interface=vlan4-infrastructure comment="Infrastructure Gateway"
/ip address add address=192.168.20.1/24 interface=vlan20-workstations comment="Workstation Gateway"
/ip address add address=192.168.38.1/24 interface=vlan38-vmotion comment="vMotion Gateway"
/ip address add address=192.168.39.1/24 interface=vlan39-vsan comment="vSAN Gateway"
/ip address add address=192.168.40.1/24 interface=vlan40-nsx-tep comment="NSX TEP Gateway"
/ip address add address=192.168.60.1/24 interface=vlan60-storage-mgmt comment="Storage Mgmt Gateway"
/ip address add address=192.168.61.1/24 interface=vlan61-storage-data comment="Storage Data Gateway"

#==============================================================================
# ROUTING CONFIGURATION
#==============================================================================

# Default route (keep existing)
/ip route add dst-address=0.0.0.0/0 gateway=192.168.3.248 comment="Default Route"

# Static routes for specific VLANs if needed
# Add specific routes here as required

# Enable IP forwarding
/ip settings set ip-forward=yes

#==============================================================================
# QoS CONFIGURATION FOR PERFORMANCE
#==============================================================================

# Queue Types for different traffic classes
/queue type
add kind=pfifo name=high-priority pfifo-limit=100 comment="High priority queue"
add kind=pfifo name=storage-traffic pfifo-limit=200 comment="Storage traffic queue"
add kind=pfifo name=standard-traffic pfifo-limit=50 comment="Standard traffic queue"

# Queue Tree for traffic shaping
/queue tree
add name=main-interface parent=global
add name=storage-class parent=main-interface priority=1 comment="Storage Traffic - Highest Priority"
add name=vmotion-class parent=main-interface priority=2 comment="vMotion Traffic - High Priority"
add name=management-class parent=main-interface priority=3 comment="Management Traffic - Medium Priority"
add name=workstation-class parent=main-interface priority=4 comment="Workstation Traffic - Standard Priority"

# Simple Queues for VLAN-based QoS
/queue simple
add name=vsan-qos target=vlan39-vsan max-limit=10G/10G priority=1/1 comment="vSAN - Highest Priority"
add name=vmotion-qos target=vlan38-vmotion max-limit=5G/5G priority=2/2 comment="vMotion - High Priority"
add name=storage-qos target=vlan60-storage-mgmt,vlan61-storage-data max-limit=8G/8G priority=1/1 comment="Storage Management & Data"
add name=nsx-qos target=vlan40-nsx-tep max-limit=2G/2G priority=3/3 comment="NSX Tunnel Endpoints"

#==============================================================================
# FIREWALL CONFIGURATION
#==============================================================================

# Input Chain Rules (connections TO the router)
/ip firewall filter

# Accept established and related connections
add action=accept chain=input connection-state=established,related comment="Allow established connections"

# Allow ICMP (ping) for troubleshooting
add action=accept chain=input protocol=icmp comment="Allow ICMP"

# Allow SSH from management networks only
add action=accept chain=input in-interface-list=management protocol=tcp dst-port=2222 \
    src-address-list=management-networks comment="Allow SSH from management"

# Allow HTTPS from management networks only
add action=accept chain=input in-interface-list=management protocol=tcp dst-port=8443 \
    src-address-list=management-networks comment="Allow HTTPS from management"

# Allow Winbox from management networks
add action=accept chain=input in-interface-list=management protocol=tcp dst-port=8291 \
    src-address-list=management-networks comment="Allow Winbox from management"

# Allow SNMP from monitoring systems
add action=accept chain=input protocol=udp dst-port=161 \
    src-address-list=monitoring-systems comment="Allow SNMP from monitoring"

# Drop invalid connections
add action=drop chain=input connection-state=invalid comment="Drop invalid connections"

# Drop all other input traffic
add action=drop chain=input comment="Drop all other input"

# Forward Chain Rules (traffic THROUGH the router)
# Accept established and related connections
add action=accept chain=forward connection-state=established,related comment="Allow established connections"

# Accept all traffic within same VLAN
add action=accept chain=forward in-interface-list=internal out-interface-list=internal comment="Allow intra-VLAN traffic"

# Allow specific inter-VLAN communication
add action=accept chain=forward src-address=192.168.3.0/24 comment="Allow from Management VLAN"
add action=accept chain=forward src-address=192.168.38.0/24 dst-address=192.168.39.0/24 comment="vMotion to vSAN"
add action=accept chain=forward src-address=192.168.39.0/24 dst-address=192.168.38.0/24 comment="vSAN to vMotion"
add action=accept chain=forward src-address=192.168.60.0/24 dst-address=192.168.61.0/24 comment="Storage Mgmt to Data"

# Drop invalid connections in forward
add action=drop chain=forward connection-state=invalid comment="Drop invalid forward connections"

# Log dropped traffic for analysis
add action=log chain=forward log-prefix="FW-DROP: " comment="Log dropped forward traffic"
add action=drop chain=forward comment="Drop all other forward traffic"

#==============================================================================
# ADDRESS LISTS FOR FIREWALL
#==============================================================================

/ip firewall address-list
add list=management-networks address=192.168.3.0/24 comment="Management Network"
add list=management-networks address=192.168.4.0/24 comment="Infrastructure Network"
add list=monitoring-systems address=192.168.3.100 comment="SNMP Monitoring Server"
add list=internal-networks address=192.168.0.0/16 comment="All internal networks"

#==============================================================================
# INTERFACE LISTS
#==============================================================================

/interface list
add name=internal comment="Internal VLANs"
add name=management comment="Management interfaces"

/interface list member
add list=internal interface=vlan1-default
add list=internal interface=vlan3-management
add list=internal interface=vlan4-infrastructure
add list=internal interface=vlan20-workstations
add list=internal interface=vlan38-vmotion
add list=internal interface=vlan39-vsan
add list=internal interface=vlan40-nsx-tep
add list=internal interface=vlan60-storage-mgmt
add list=internal interface=vlan61-storage-data

add list=management interface=vlan3-management
add list=management interface=ether1

#==============================================================================
# MONITORING AND LOGGING
#==============================================================================

# SNMP Configuration
/snmp set contact="Network Administrator" enabled=yes engine-id="" location="Data Center - 100G Switch"
/snmp community set [find default=yes] name=public-read security=none

# Logging Configuration
/system logging action
add name=remote-syslog target=remote remote=192.168.3.100 remote-port=514 src-address=192.168.3.1

/system logging
add action=remote-syslog disabled=no prefix="" topics=info,warning,error,critical
add action=memory disabled=no prefix="" topics=warning,error,critical
add action=disk disabled=no prefix="" topics=system,firewall

#==============================================================================
# BACKUP AND MAINTENANCE
#==============================================================================

# Scheduler for automatic backups
/system scheduler
add name=daily-backup interval=1d on-event="/system backup save name=(\"backup-\" . [/system clock get date]); /system script run cleanup-old-backups" \
    policy=reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=02:00:00 comment="Daily configuration backup"

# Script to cleanup old backups (keep only 7 days)
/system script
add name=cleanup-old-backups policy=reboot,read,write,policy,test,password,sniff,sensitive,romon source={
    :local backupAge 7d;
    :local currentDate [/system clock get date];
    :foreach backup in=[/file find name~"backup-"] do={
        :local backupDate [/file get $backup creation-time];
        :if (($currentDate - $backupDate) > $backupAge) do={
            /file remove $backup;
            :log info ("Removed old backup: " . [/file get $backup name]);
        }
    }
}

#==============================================================================
# SYSTEM HARDENING
#==============================================================================

# MAC Server settings (disable on WAN interfaces)
/tool mac-server set allowed-interface-list=management
/tool mac-server mac-winbox set allowed-interface-list=management

# Neighbor Discovery (disable on WAN)
/ip neighbor discovery-settings set discover-interface-list=management

# Bandwidth Test (disable for security)
/tool bandwidth-server set enabled=no

#==============================================================================
# FINAL NOTES AND COMMENTS
#==============================================================================

/system note set note="100G-1 Secured Configuration - Applied $(date)" show-at-login=yes

# Configuration completed
# Remember to:
# 1. Change all default passwords
# 2. Configure certificate-based SSH authentication
# 3. Set up proper monitoring and alerting
# 4. Test all VLAN connectivity
# 5. Verify firewall rules are working as expected
# 6. Set up automated configuration backups to external storage