#!/usr/bin/env python3

"""
MikroTik API Configuration Extractor

This script connects to a MikroTik router via API and extracts the configuration
for use in reusable scripts. It generates both RouterOS script format and
structured data formats.

Requirements:
    pip install routeros-api

Usage:
    python3 extract-mikrotik-config.py [options]
"""

import argparse
import json
import sys
import getpass
from datetime import datetime
from pathlib import Path
import routeros_api
from routeros_api.exceptions import RouterOsApiError


class MikroTikConfigExtractor:
    def __init__(self, host, username, password, port=8728, use_ssl=False):
        self.host = host
        self.username = username
        self.password = password
        self.port = port
        self.use_ssl = use_ssl
        self.connection = None
        self.api = None
        
    def connect(self):
        """Connect to MikroTik API"""
        try:
            print(f"Connecting to MikroTik at {self.host}:{self.port}...")
            self.connection = routeros_api.RouterOsApiPool(
                self.host,
                username=self.username,
                password=self.password,
                port=self.port,
                use_ssl=self.use_ssl,
                plaintext_login=True
            )
            self.api = self.connection.get_api()
            print("✅ Connected successfully!")
            return True
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from MikroTik API"""
        if self.connection:
            self.connection.disconnect()
            print("🔌 Disconnected from MikroTik")
    
    def get_system_info(self):
        """Get system information"""
        try:
            identity = self.api.get_resource('/system/identity')
            clock = self.api.get_resource('/system/clock')
            resource = self.api.get_resource('/system/resource')
            
            return {
                'identity': identity.get(),
                'clock': clock.get(),
                'resource': resource.get()
            }
        except Exception as e:
            print(f"⚠️ Warning: Could not get system info: {e}")
            return {}
    
    def get_interfaces(self):
        """Get all interfaces"""
        try:
            interfaces = self.api.get_resource('/interface')
            bridge = self.api.get_resource('/interface/bridge')
            bridge_port = self.api.get_resource('/interface/bridge/port')
            vlan = self.api.get_resource('/interface/vlan')
            
            return {
                'interfaces': interfaces.get(),
                'bridge': bridge.get(),
                'bridge_port': bridge_port.get(),
                'vlan': vlan.get()
            }
        except Exception as e:
            print(f"❌ Error getting interfaces: {e}")
            return {}
    
    def get_bridge_config(self):
        """Get bridge and VLAN configuration"""
        try:
            bridge_vlan = self.api.get_resource('/interface/bridge/vlan')
            
            return {
                'bridge_vlan': bridge_vlan.get()
            }
        except Exception as e:
            print(f"❌ Error getting bridge config: {e}")
            return {}
    
    def get_ip_config(self):
        """Get IP configuration"""
        try:
            addresses = self.api.get_resource('/ip/address')
            routes = self.api.get_resource('/ip/route')
            dns = self.api.get_resource('/ip/dns')
            dhcp_server = self.api.get_resource('/ip/dhcp-server')
            dhcp_network = self.api.get_resource('/ip/dhcp-server/network')
            pools = self.api.get_resource('/ip/pool')
            
            return {
                'addresses': addresses.get(),
                'routes': routes.get(),
                'dns': dns.get(),
                'dhcp_server': dhcp_server.get(),
                'dhcp_network': dhcp_network.get(),
                'pools': pools.get()
            }
        except Exception as e:
            print(f"❌ Error getting IP config: {e}")
            return {}
    
    def get_services(self):
        """Get service configuration"""
        try:
            services = self.api.get_resource('/ip/service')
            
            return {
                'services': services.get()
            }
        except Exception as e:
            print(f"❌ Error getting services: {e}")
            return {}
    
    def get_firewall_config(self):
        """Get firewall configuration"""
        try:
            filter_rules = self.api.get_resource('/ip/firewall/filter')
            
            return {
                'filter': filter_rules.get()
            }
        except Exception as e:
            print(f"❌ Error getting firewall config: {e}")
            return {}
    
    def get_snmp_config(self):
        """Get SNMP configuration"""
        try:
            snmp = self.api.get_resource('/snmp')
            snmp_community = self.api.get_resource('/snmp/community')
            
            return {
                'snmp': snmp.get(),
                'snmp_community': snmp_community.get()
            }
        except Exception as e:
            print(f"⚠️ Warning: Could not get SNMP config: {e}")
            return {}
    
    def extract_full_config(self):
        """Extract complete configuration"""
        print("🔍 Extracting configuration...")
        
        config = {
            'extraction_info': {
                'timestamp': datetime.now().isoformat(),
                'host': self.host,
                'extracted_by': 'MikroTik Config Extractor'
            },
            'system': self.get_system_info(),
            'interfaces': self.get_interfaces(),
            'bridge': self.get_bridge_config(),
            'ip': self.get_ip_config(),
            'services': self.get_services(),
            'firewall': self.get_firewall_config(),
            'snmp': self.get_snmp_config()
        }
        
        print("✅ Configuration extracted successfully!")
        return config
    
    def generate_routeros_script(self, config, filename):
        """Generate RouterOS script from configuration"""
        print(f"📝 Generating RouterOS script: {filename}")
        
        with open(filename, 'w') as f:
            f.write("# MikroTik RouterOS Configuration Script\n")
            f.write(f"# Extracted from {self.host} on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("# Generated by MikroTik Config Extractor\n\n")
            
            # System Identity
            system_info = config.get('system', {})
            if 'identity' in system_info and system_info['identity']:
                identity = system_info['identity'][0]
                if 'name' in identity:
                    f.write(f"# System Identity\n")
                    f.write(f"/system identity set name=\"{identity['name']}\"\n\n")
            
            # Bridges
            interfaces = config.get('interfaces', {})
            if 'bridge' in interfaces:
                f.write("# Bridge Configuration\n")
                for bridge in interfaces['bridge']:
                    bridge_name = bridge.get('name', '')
                    protocol_mode = bridge.get('protocol-mode', 'none')
                    vlan_filtering = bridge.get('vlan-filtering', 'no')
                    
                    f.write(f"/interface bridge add name={bridge_name}")
                    if protocol_mode != 'none':
                        f.write(f" protocol-mode={protocol_mode}")
                    if vlan_filtering == 'yes':
                        f.write(f" vlan-filtering={vlan_filtering}")
                    f.write(f" comment=\"Extracted bridge\"\n")
                f.write("\n")
            
            # Bridge Ports
            if 'bridge_port' in interfaces:
                f.write("# Bridge Port Configuration\n")
                for port in interfaces['bridge_port']:
                    bridge_name = port.get('bridge', '')
                    interface = port.get('interface', '')
                    pvid = port.get('pvid', '')
                    
                    f.write(f"/interface bridge port add bridge={bridge_name} interface={interface}")
                    if pvid and pvid != '1':
                        f.write(f" pvid={pvid}")
                    f.write("\n")
                f.write("\n")
            
            # VLAN Interfaces
            if 'vlan' in interfaces:
                f.write("# VLAN Interface Configuration\n")
                for vlan in interfaces['vlan']:
                    name = vlan.get('name', '')
                    vlan_id = vlan.get('vlan-id', '')
                    interface = vlan.get('interface', '')
                    comment = vlan.get('comment', '')
                    
                    f.write(f"/interface vlan add name={name} vlan-id={vlan_id} interface={interface}")
                    if comment:
                        f.write(f" comment=\"{comment}\"")
                    f.write("\n")
                f.write("\n")
            
            # Bridge VLAN Configuration
            bridge_config = config.get('bridge', {})
            if 'bridge_vlan' in bridge_config:
                f.write("# Bridge VLAN Configuration\n")
                for bvlan in bridge_config['bridge_vlan']:
                    bridge_name = bvlan.get('bridge', '')
                    vlan_ids = bvlan.get('vlan-ids', '')
                    tagged = bvlan.get('tagged', '')
                    untagged = bvlan.get('untagged', '')
                    
                    f.write(f"/interface bridge vlan add bridge={bridge_name} vlan-ids={vlan_ids}")
                    if tagged:
                        f.write(f" tagged={tagged}")
                    if untagged:
                        f.write(f" untagged={untagged}")
                    f.write("\n")
                f.write("\n")
            
            # IP Addresses
            ip_config = config.get('ip', {})
            if 'addresses' in ip_config:
                f.write("# IP Address Configuration\n")
                for addr in ip_config['addresses']:
                    address = addr.get('address', '')
                    interface = addr.get('interface', '')
                    comment = addr.get('comment', '')
                    
                    f.write(f"/ip address add address={address} interface={interface}")
                    if comment:
                        f.write(f" comment=\"{comment}\"")
                    f.write("\n")
                f.write("\n")
            
            # Routes
            if 'routes' in ip_config:
                f.write("# Route Configuration\n")
                for route in ip_config['routes']:
                    if route.get('dynamic') == 'true':  # Skip dynamic routes
                        continue
                    
                    dst_address = route.get('dst-address', '')
                    gateway = route.get('gateway', '')
                    comment = route.get('comment', '')
                    
                    if dst_address and gateway:
                        f.write(f"/ip route add dst-address={dst_address} gateway={gateway}")
                        if comment:
                            f.write(f" comment=\"{comment}\"")
                        f.write("\n")
                f.write("\n")
            
            # DNS Configuration
            if 'dns' in ip_config and ip_config['dns']:
                dns = ip_config['dns'][0]
                servers = dns.get('servers', '')
                if servers:
                    f.write("# DNS Configuration\n")
                    f.write(f"/ip dns set servers={servers}\n\n")
            
            # DHCP Pools
            if 'pools' in ip_config:
                f.write("# DHCP Pool Configuration\n")
                for pool in ip_config['pools']:
                    name = pool.get('name', '')
                    ranges = pool.get('ranges', '')
                    
                    f.write(f"/ip pool add name={name} ranges={ranges}\n")
                f.write("\n")
            
            # DHCP Server Networks
            if 'dhcp_network' in ip_config:
                f.write("# DHCP Server Network Configuration\n")
                for network in ip_config['dhcp_network']:
                    address = network.get('address', '')
                    gateway = network.get('gateway', '')
                    dns_server = network.get('dns-server', '')
                    
                    f.write(f"/ip dhcp-server network add address={address}")
                    if gateway:
                        f.write(f" gateway={gateway}")
                    if dns_server:
                        f.write(f" dns-server={dns_server}")
                    f.write("\n")
                f.write("\n")
            
            # DHCP Servers
            if 'dhcp_server' in ip_config:
                f.write("# DHCP Server Configuration\n")
                for server in ip_config['dhcp_server']:
                    name = server.get('name', '')
                    interface = server.get('interface', '')
                    address_pool = server.get('address-pool', '')
                    disabled = server.get('disabled', 'no')
                    
                    f.write(f"/ip dhcp-server add name={name}")
                    if interface:
                        f.write(f" interface={interface}")
                    if address_pool:
                        f.write(f" address-pool={address_pool}")
                    if disabled == 'no':
                        f.write(f" disabled=no")
                    f.write("\n")
                f.write("\n")
            
            # Services
            services_config = config.get('services', {})
            if 'services' in services_config:
                f.write("# Service Configuration\n")
                for service in services_config['services']:
                    name = service.get('name', '')
                    disabled = service.get('disabled', 'no')
                    port = service.get('port', '')
                    
                    f.write(f"/ip service set {name} disabled={disabled}")
                    if port and port != service.get('default-port', port):
                        f.write(f" port={port}")
                    f.write("\n")
                f.write("\n")
            
            # Firewall Filter Rules
            firewall_config = config.get('firewall', {})
            if 'filter' in firewall_config:
                f.write("# Firewall Filter Rules\n")
                for rule in firewall_config['filter']:
                    if rule.get('dynamic') == 'true':  # Skip dynamic rules
                        continue
                    
                    chain = rule.get('chain', '')
                    action = rule.get('action', '')
                    protocol = rule.get('protocol', '')
                    src_address = rule.get('src-address', '')
                    dst_address = rule.get('dst-address', '')
                    dst_port = rule.get('dst-port', '')
                    in_interface = rule.get('in-interface', '')
                    connection_state = rule.get('connection-state', '')
                    comment = rule.get('comment', '')
                    
                    f.write(f"/ip firewall filter add chain={chain} action={action}")
                    if protocol:
                        f.write(f" protocol={protocol}")
                    if src_address:
                        f.write(f" src-address={src_address}")
                    if dst_address:
                        f.write(f" dst-address={dst_address}")
                    if dst_port:
                        f.write(f" dst-port={dst_port}")
                    if in_interface:
                        f.write(f" in-interface={in_interface}")
                    if connection_state:
                        f.write(f" connection-state={connection_state}")
                    if comment:
                        f.write(f" comment=\"{comment}\"")
                    f.write("\n")
                f.write("\n")
            
            # SNMP Configuration
            snmp_config = config.get('snmp', {})
            if 'snmp' in snmp_config and snmp_config['snmp']:
                snmp = snmp_config['snmp'][0]
                enabled = snmp.get('enabled', 'no')
                contact = snmp.get('contact', '')
                location = snmp.get('location', '')
                
                if enabled == 'yes':
                    f.write("# SNMP Configuration\n")
                    f.write(f"/snmp set enabled=yes")
                    if contact:
                        f.write(f" contact={contact}")
                    if location:
                        f.write(f" location=\"{location}\"")
                    f.write("\n")
                    
                    # SNMP Communities
                    if 'snmp_community' in snmp_config:
                        for community in snmp_config['snmp_community']:
                            name = community.get('name', '')
                            if name and name != 'public':
                                f.write(f"/snmp community set [find default=yes] name=\"{name}\"\n")
                    f.write("\n")
        
        print(f"✅ RouterOS script generated: {filename}")
    
    def generate_env_file(self, config, filename):
        """Generate environment file for use with provision script"""
        print(f"🔧 Generating environment file: {filename}")
        
        with open(filename, 'w') as f:
            f.write("# MikroTik Configuration Environment File\n")
            f.write(f"# Extracted from {self.host} on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("# Generated by MikroTik Config Extractor\n\n")
            
            f.write("# MikroTik Connection Settings\n")
            f.write(f"MIKROTIK_IP=\"{self.host}\"\n")
            f.write(f"MIKROTIK_USER=\"{self.username}\"\n")
            f.write("MIKROTIK_PASSWORD=\"\"\n\n")
            
            # Extract VLAN information
            interfaces = config.get('interfaces', {})
            vlans = {}
            
            if 'vlan' in interfaces:
                for vlan in interfaces['vlan']:
                    vlan_id = vlan.get('vlan-id', '')
                    comment = vlan.get('comment', '').lower()
                    name = vlan.get('name', '').lower()
                    
                    # Try to identify VLAN types based on comments or names
                    if 'management' in comment or 'mgmt' in comment or 'management' in name:
                        vlans['mgmt'] = vlan_id
                    elif 'vmotion' in comment or 'vmotion' in name:
                        vlans['vmotion'] = vlan_id
                    elif 'vsan' in comment or 'vsan' in name:
                        vlans['vsan'] = vlan_id
                    elif 'tep' in comment or 'tep' in name:
                        if 'edge' in comment or 'edge' in name:
                            vlans['edge_tep'] = vlan_id
                        else:
                            vlans['tep'] = vlan_id
                    elif 'vm' in comment or 'vm' in name:
                        vlans['vm'] = vlan_id
                    elif 'nfs' in comment or 'storage' in comment or 'nfs' in name:
                        vlans['nfs'] = vlan_id
            
            # Write VLAN configuration
            f.write("# VCF VLAN Configuration\n")
            f.write(f"MGMT_VLAN_ID=\"{vlans.get('mgmt', '100')}\"\n")
            f.write(f"VMOTION_VLAN_ID=\"{vlans.get('vmotion', '101')}\"\n")
            f.write(f"VSAN_VLAN_ID=\"{vlans.get('vsan', '102')}\"\n")
            f.write(f"TEP_VLAN_ID=\"{vlans.get('tep', '103')}\"\n")
            if 'edge_tep' in vlans:
                f.write(f"EDGE_TEP_VLAN_ID=\"{vlans.get('edge_tep')}\"\n")
            if 'vm' in vlans:
                f.write(f"VM_VLAN_ID=\"{vlans.get('vm')}\"\n")
            if 'nfs' in vlans:
                f.write(f"NFS_VLAN_ID=\"{vlans.get('nfs')}\"\n")
            f.write("\n")
            
            # Extract network information
            ip_config = config.get('ip', {})
            if 'addresses' in ip_config:
                networks = {}
                for addr in ip_config['addresses']:
                    interface = addr.get('interface', '')
                    address = addr.get('address', '')
                    
                    if interface.startswith('vlan') and address:
                        vlan_id = interface.replace('vlan', '')
                        network = address.split('/')[0].rsplit('.', 1)[0] + '.0/' + address.split('/')[1]
                        
                        for vlan_type, vid in vlans.items():
                            if vid == vlan_id:
                                networks[vlan_type] = network
                                break
                
                f.write("# Network Configuration\n")
                if 'mgmt' in networks:
                    f.write(f"MGMT_NETWORK=\"{networks['mgmt']}\"\n")
                if 'vmotion' in networks:
                    f.write(f"VMOTION_NETWORK=\"{networks['vmotion']}\"\n")
                if 'vsan' in networks:
                    f.write(f"VSAN_NETWORK=\"{networks['vsan']}\"\n")
                if 'tep' in networks:
                    f.write(f"TEP_NETWORK=\"{networks['tep']}\"\n")
                if 'edge_tep' in networks:
                    f.write(f"EDGE_TEP_NETWORK=\"{networks['edge_tep']}\"\n")
                if 'vm' in networks:
                    f.write(f"VM_NETWORK=\"{networks['vm']}\"\n")
                if 'nfs' in networks:
                    f.write(f"NFS_NETWORK=\"{networks['nfs']}\"\n")
                f.write("\n")
            
            # Extract bridge information
            bridge_name = "br-vcf"  # default
            if 'bridge' in interfaces and interfaces['bridge']:
                bridge_name = interfaces['bridge'][0].get('name', 'br-vcf')
            
            f.write("# Bridge Configuration\n")
            f.write(f"BRIDGE_NAME=\"{bridge_name}\"\n")
            f.write("BRIDGE_VLAN_FILTERING=\"yes\"\n\n")
            
            # Extract interface information
            trunk_ports = []
            access_ports = []
            uplink_ports = []
            
            if 'bridge_port' in interfaces:
                for port in interfaces['bridge_port']:
                    interface = port.get('interface', '')
                    pvid = port.get('pvid', '1')
                    
                    if interface.startswith('ether'):
                        if pvid == '1':  # Likely trunk port
                            trunk_ports.append(interface)
                        else:  # Access port
                            access_ports.append(interface)
            
            # Try to identify uplinks (usually highest numbered ports)
            if trunk_ports:
                # Sort ports and assume highest numbers are uplinks
                sorted_ports = sorted(trunk_ports, key=lambda x: int(x.replace('ether', '')))
                if len(sorted_ports) > 3:
                    uplink_ports = sorted_ports[-2:]  # Last 2 ports
                    trunk_ports = sorted_ports[:-2]  # All but last 2
                else:
                    uplink_ports = [sorted_ports[-1]]  # Last port
                    trunk_ports = sorted_ports[:-1] if len(sorted_ports) > 1 else []
            
            f.write("# Interface Configuration\n")
            if uplink_ports:
                f.write(f"UPLINK_INTERFACES=\"{','.join(uplink_ports)}\"\n")
            if trunk_ports:
                f.write(f"TRUNK_INTERFACES=\"{','.join(trunk_ports)}\"\n")
            if access_ports:
                f.write(f"MGMT_ACCESS_PORTS=\"{','.join(access_ports[:2])}\"\n")  # First 2 as mgmt
            f.write("\n")
            
            # DNS Configuration
            if 'dns' in ip_config and ip_config['dns']:
                dns = ip_config['dns'][0]
                servers = dns.get('servers', '8.8.8.8,8.8.4.4')
                f.write("# DNS Configuration\n")
                f.write(f"DNS_SERVERS=\"{servers}\"\n\n")
            
            # SNMP Configuration
            snmp_config = config.get('snmp', {})
            if 'snmp' in snmp_config and snmp_config['snmp']:
                snmp = snmp_config['snmp'][0]
                enabled = snmp.get('enabled', 'no')
                contact = snmp.get('contact', 'admin')
                location = snmp.get('location', 'Datacenter')
                
                f.write("# SNMP Configuration\n")
                f.write(f"ENABLE_SNMP=\"{enabled}\"\n")
                if 'snmp_community' in snmp_config and snmp_config['snmp_community']:
                    community = snmp_config['snmp_community'][0].get('name', 'public')
                    f.write(f"SNMP_COMMUNITY=\"{community}\"\n")
                f.write(f"SNMP_LOCATION=\"{location}\"\n")
        
        print(f"✅ Environment file generated: {filename}")


def main():
    parser = argparse.ArgumentParser(description='Extract MikroTik configuration via API')
    parser.add_argument('--host', '-H', default='192.168.3.1',
                      help='MikroTik host IP (default: 192.168.3.1)')
    parser.add_argument('--port', '-P', type=int, default=8728,
                      help='API port (default: 8728)')
    parser.add_argument('--ssl', action='store_true',
                      help='Use SSL connection (port 8729)')
    parser.add_argument('--username', '-u', default='admin',
                      help='Username (default: admin)')
    parser.add_argument('--password', '-p',
                      help='Password (will prompt if not provided)')
    parser.add_argument('--output-dir', '-o', default='.',
                      help='Output directory (default: current directory)')
    parser.add_argument('--json', action='store_true',
                      help='Also output raw JSON configuration')
    parser.add_argument('--prefix', default='extracted',
                      help='Output file prefix (default: extracted)')
    
    args = parser.parse_args()
    
    # Handle SSL port
    if args.ssl and args.port == 8728:
        args.port = 8729
    
    # Get password if not provided
    password = args.password
    if not password:
        password = getpass.getpass(f"Enter password for {args.username}@{args.host}: ")
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Generate filenames
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    host_clean = args.host.replace('.', '_')
    
    rsc_file = output_dir / f"{args.prefix}_{host_clean}_{timestamp}.rsc"
    env_file = output_dir / f"{args.prefix}_{host_clean}_{timestamp}.env"
    json_file = output_dir / f"{args.prefix}_{host_clean}_{timestamp}.json"
    
    # Initialize extractor
    extractor = MikroTikConfigExtractor(
        args.host, args.username, password, args.port, args.ssl
    )
    
    try:
        # Connect and extract
        if not extractor.connect():
            sys.exit(1)
        
        config = extractor.extract_full_config()
        
        # Generate outputs
        extractor.generate_routeros_script(config, rsc_file)
        extractor.generate_env_file(config, env_file)
        
        if args.json:
            with open(json_file, 'w') as f:
                json.dump(config, f, indent=2, default=str)
            print(f"✅ JSON configuration saved: {json_file}")
        
        print(f"\n🎉 Configuration extraction completed!")
        print(f"📁 Files generated:")
        print(f"   • RouterOS Script: {rsc_file}")
        print(f"   • Environment File: {env_file}")
        if args.json:
            print(f"   • JSON Data: {json_file}")
        
        print(f"\n💡 Usage:")
        print(f"   • Import RouterOS script: scp {rsc_file} admin@{args.host}:/ && ssh admin@{args.host} '/import file-name={rsc_file.name}'")
        print(f"   • Use with provisioning script: ./provision-mikrotik-vcf.sh -c {env_file}")
        
    except KeyboardInterrupt:
        print("\n⏹️ Extraction cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error during extraction: {e}")
        sys.exit(1)
    finally:
        extractor.disconnect()


if __name__ == '__main__':
    main()