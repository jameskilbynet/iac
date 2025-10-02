# MikroTik Configuration Improvement Implementation Guide

## ⚠️ **CRITICAL SAFETY WARNINGS**

**BEFORE STARTING:**
1. **Create a full backup** of your current configuration
2. **Schedule maintenance window** - this will cause network disruption
3. **Have console access** available in case of lockout
4. **Test in a lab environment** first if possible
5. **Have rollback plan ready**

## 📋 **Pre-Implementation Checklist**

### Backup Current Configuration
```bash
# Create backup via SSH
ssh admin@192.168.3.1
/system backup save name=pre-upgrade-backup
/export file=pre-upgrade-config

# Download backups to your local machine
scp admin@192.168.3.1:pre-upgrade-backup.backup ./
scp admin@192.168.3.1:pre-upgrade-config.rsc ./
```

### Document Current Network
- [ ] Document all connected devices and their requirements
- [ ] Note current VLAN assignments for each port
- [ ] Record any custom configurations not in the extracted config
- [ ] Identify critical services that cannot tolerate downtime

## 🚀 **Implementation Phases**

### Phase 1: Security Hardening (Low Risk)
**Impact:** Minimal network disruption  
**Duration:** 15-20 minutes  
**Rollback:** Easy

#### Step 1.1: Disable Insecure Services
```bash
/ip service set ftp disabled=yes
/ip service set telnet disabled=yes  
/ip service set www disabled=yes
/ip service set dhcp disabled=yes
/ip service set btest disabled=yes
/ip service set discover disabled=yes
```

#### Step 1.2: Change Service Ports (Security through Obscurity)
```bash
/ip service set ssh port=2222
/ip service set www-ssl port=8443
/ip service set api disabled=yes
```

#### Step 1.3: Create New Admin Users
```bash
/user add name=netadmin group=full password=YourSecurePassword123!
/user add name=readonly group=read password=YourReadOnlyPass123!
```

**⚠️ WARNING:** Do NOT disable the default admin user until you've verified the new users work!

### Phase 2: Monitoring and Logging (Low Risk)
**Impact:** No network disruption  
**Duration:** 10 minutes  
**Rollback:** Easy

#### Step 2.1: Configure SNMP
```bash
/snmp set contact="Your Name" enabled=yes location="Data Center"
/snmp community set [find default=yes] name=your-snmp-community
```

#### Step 2.2: Set up Logging
```bash
# Replace 192.168.3.100 with your syslog server IP
/system logging action add name=remote-syslog target=remote remote=192.168.3.100 remote-port=514
/system logging add action=remote-syslog topics=info,warning,error,critical
```

### Phase 3: Network Architecture Improvements (HIGH RISK)
**Impact:** NETWORK OUTAGE DURING IMPLEMENTATION  
**Duration:** 45-60 minutes  
**Rollback:** Requires backup restoration

#### Step 3.1: Prepare for Bridge Replacement
```bash
# Document current bridge ports before changes
/interface bridge port print detail
/interface bridge vlan print detail
```

#### Step 3.2: Create New Bridge (OUTAGE BEGINS)
```bash
# Remove old bridge (THIS WILL CAUSE OUTAGE)
/interface bridge remove [find name=bridge]

# Create new bridge with VLAN filtering
/interface bridge add name=br-main protocol-mode=rstp vlan-filtering=yes fast-forward=yes
```

#### Step 3.3: Re-add Bridge Ports
```bash
# Critical: Add uplink first to minimize outage duration
/interface bridge port add bridge=br-main interface=qsfp28-1-1 comment="UPLINK"

# Add Nutanix nodes (priority order)
/interface bridge port add bridge=br-main interface=qsfp28-1-2 comment="uk-bhr-p-ntnx-1"
/interface bridge port add bridge=br-main interface=qsfp28-1-3 comment="uk-bhr-p-ntnx-2"
/interface bridge port add bridge=br-main interface=qsfp28-3-1 comment="uk-bhr-p-ntnx-1-backup"
/interface bridge port add bridge=br-main interface=qsfp28-3-2 comment="uk-bhr-p-ntnx-2-backup"
/interface bridge port add bridge=br-main interface=qsfp28-3-3 comment="uk-bhr-p-ntnx-3"
/interface bridge port add bridge=br-main interface=qsfp28-3-4 comment="uk-bhr-p-ntnx-3-backup"

# Add storage
/interface bridge port add bridge=br-main interface=qsfp28-1-4 comment="StoreServ1"
/interface bridge port add bridge=br-main interface=qsfp28-2-4 comment="Storeserv2"

# Add workstations
/interface bridge port add bridge=br-main interface=qsfp28-2-2 comment="Z840-1"
/interface bridge port add bridge=br-main interface=qsfp28-2-3 comment="Z840-2"
/interface bridge port add bridge=br-main interface=qsfp28-4-1 comment="ESX-C"
```

#### Step 3.4: Configure VLAN Interfaces
```bash
/interface vlan add interface=br-main name=vlan1-default vlan-id=1
/interface vlan add interface=br-main name=vlan3-management vlan-id=3
/interface vlan add interface=br-main name=vlan4-infrastructure vlan-id=4
/interface vlan add interface=br-main name=vlan20-workstations vlan-id=20
/interface vlan add interface=br-main name=vlan38-vmotion vlan-id=38
/interface vlan add interface=br-main name=vlan39-vsan vlan-id=39
/interface vlan add interface=br-main name=vlan40-nsx-tep vlan-id=40
/interface vlan add interface=br-main name=vlan60-storage-mgmt vlan-id=60
/interface vlan add interface=br-main name=vlan61-storage-data vlan-id=61
```

#### Step 3.5: Configure Bridge VLANs (Critical Section)
Apply the bridge VLAN configuration from the improved-config.rsc file. **This is the most critical part - any errors here will cause connectivity issues.**

### Phase 4: Firewall Implementation (MEDIUM RISK)
**Impact:** May block traffic if misconfigured  
**Duration:** 20-30 minutes  
**Rollback:** Remove firewall rules

#### Step 4.1: Create Address Lists First
```bash
/ip firewall address-list add list=management-networks address=192.168.3.0/24
/ip firewall address-list add list=management-networks address=192.168.4.0/24
/ip firewall address-list add list=monitoring-systems address=192.168.3.100
```

#### Step 4.2: Create Interface Lists
```bash
/interface list add name=internal
/interface list add name=management

# Add interfaces to lists
/interface list member add list=management interface=vlan3-management
/interface list member add list=management interface=ether1
# Add all VLAN interfaces to internal list...
```

#### Step 4.3: Implement Firewall Rules Carefully
Start with permissive rules and gradually tighten. **Test connectivity after each rule!**

### Phase 5: QoS Configuration (Low Risk)
**Impact:** Minimal - improves performance  
**Duration:** 15 minutes  
**Rollback:** Remove queue configurations

Apply QoS configurations from the improved config file.

## 🔍 **Verification Steps**

After each phase, verify:

### Network Connectivity
```bash
# Test from switch
/ping 192.168.3.248  # Default gateway
/ping 8.8.8.8        # Internet connectivity

# Test VLAN connectivity
/ping src-address=192.168.38.1 192.168.39.1  # vMotion to vSAN

# Check bridge status
/interface bridge print
/interface bridge port print
/interface bridge vlan print
```

### Device Connectivity
- [ ] Verify Nutanix nodes are reachable
- [ ] Check storage devices connectivity
- [ ] Test workstation network access
- [ ] Validate ESXi management access

### Service Verification
```bash
# Check running services
/ip service print

# Verify firewall rules
/ip firewall filter print

# Check QoS queues
/queue simple print
```

## 🚨 **Rollback Procedures**

### Emergency Rollback (If things go wrong)
```bash
# Quick rollback to previous backup
/system reset-configuration keep-users=no no-defaults=yes skip-backup=yes

# Then restore backup
/system backup load name=pre-upgrade-backup
```

### Partial Rollback Options
- **Services only:** Re-enable services if locked out
- **Bridge only:** Recreate original bridge configuration
- **Firewall only:** Clear all firewall rules: `/ip firewall filter remove [find]`

## 📊 **Expected Performance Improvements**

After implementation, you should see:

1. **Security Improvements:**
   - Reduced attack surface
   - Better access control
   - Audit logging enabled

2. **Network Performance:**
   - Proper QoS for storage traffic
   - Optimized VLAN structure  
   - Better traffic prioritization

3. **Operational Benefits:**
   - Automated backups
   - Centralized logging
   - SNMP monitoring ready

## 🔧 **Post-Implementation Tasks**

### Day 1 (Immediate)
- [ ] Monitor logs for errors
- [ ] Verify all critical services are working
- [ ] Test failover scenarios
- [ ] Update documentation

### Week 1 (Short-term)
- [ ] Performance monitoring validation
- [ ] Security scan to verify hardening
- [ ] Backup verification
- [ ] User training if needed

### Month 1 (Long-term)
- [ ] Review firewall logs for optimization
- [ ] QoS tuning based on usage patterns
- [ ] Consider certificate-based SSH authentication
- [ ] Plan next security review

## 📞 **Emergency Contacts**

Before starting, ensure you have:
- Console access to the switch
- Contact information for:
  - Network team members
  - Applications teams
  - Storage administrators
  - Virtualization administrators

## 📈 **Success Metrics**

Measure success by:
- Zero unplanned outages post-implementation
- Improved security posture (vulnerability scan)
- Better network performance (latency/throughput tests)
- Successful automated backups
- Functional monitoring and alerting

---

**Remember:** This is a significant network change. Take your time, test thoroughly, and don't hesitate to rollback if issues arise. It's better to implement in phases over several maintenance windows than to rush and cause extended outages.