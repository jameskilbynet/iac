# SQL Server on vSphere - Terraform Deployment

This Terraform configuration deploys a Windows SQL Server virtual machine to VMware vSphere following SQL Server best practices.

## SQL Server Best Practices Implemented

### 1. **Separate Disk Configuration**
- **C: Drive (OS)** - Operating system and SQL Server binaries
- **D: Drive (Data)** - SQL Server data files (.mdf)
- **E: Drive (Logs)** - SQL Server transaction log files (.ldf)
- **T: Drive (TempDB)** - TempDB database (isolated to prevent I/O contention)
- **B: Drive (Backup)** - Optional backup storage

This separation provides:
- Better I/O performance
- Easier capacity management
- Improved troubleshooting
- Reduced I/O contention

### 2. **Storage Configuration**
- **Thick Eager Zeroed Disks**: Default configuration for production workloads (eagerly_scrub = true)
- **PVSCSI Controller**: Paravirtual SCSI adapter for optimal performance
- **Disk UUID Enabled**: Required for proper disk identification

### 3. **CPU Configuration**
- **Hot Add Disabled**: CPU hot add is disabled by default (can cause issues with SQL Server licensing and NUMA)
- **NUMA Awareness**: Configurable cores per socket for proper NUMA topology
- **Default**: 8 vCPUs with 4 cores per socket

### 4. **Memory Configuration**
- **Memory Reservation**: Full memory reservation enabled by default for production workloads
- **Hot Add Disabled**: Memory hot add disabled (can cause SQL Server performance issues)
- **Default**: 32GB RAM

### 5. **VMware Settings**
- **Latency Sensitivity**: Configurable (normal by default, can be set to high for production)
- **vMotion Support**: Fully compatible with vMotion
- **Disk UUID**: Enabled for Windows clustering support

## Prerequisites

1. **VMware vSphere Environment**
   - vSphere 6.7 or later
   - A Windows Server template with VMware Tools installed

2. **Terraform**
   - Terraform >= 1.0.0
   - vSphere provider >= 2.13.0

3. **Windows Template**
   - Windows Server 2019 or 2022 recommended
   - VMware Tools installed and running
   - Sysprep prepared (for customization to work)

## Quick Start

1. **Clone or navigate to this directory**
   ```bash
   cd Deploy-SQLServer
   ```

2. **Copy and customize the variables file**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your environment details
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the deployment plan**
   ```bash
   terraform plan
   ```

5. **Deploy the SQL Server VM**
   ```bash
   terraform apply
   ```

## Configuration Options

### Production SQL Server (High Performance)
```hcl
num_cpus                   = 16
cores_per_socket           = 8
memory                     = 65536  # 64GB
memory_reservation_enabled = true
latency_sensitivity        = "high"
thin_provisioned          = false
eagerly_scrub             = true
```

### Development SQL Server (Cost Optimized)
```hcl
num_cpus                   = 4
cores_per_socket           = 2
memory                     = 16384  # 16GB
memory_reservation_enabled = false
latency_sensitivity        = "normal"
thin_provisioned          = true
eagerly_scrub             = false
```

## Post-Deployment Steps

After the VM is deployed, you'll need to:

1. **Initialize and format additional disks** (D:, E:, T:, B:)
   ```powershell
   # Connect to the VM and run in PowerShell as Administrator
   
   # Initialize all raw disks
   Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT
   
   # Create and format D: drive (SQL Data)
   New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL_Data" -AllocationUnitSize 65536 -Confirm:$false
   
   # Create and format E: drive (SQL Logs)
   New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter E | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL_Logs" -AllocationUnitSize 65536 -Confirm:$false
   
   # Create and format T: drive (TempDB)
   New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter T | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL_TempDB" -AllocationUnitSize 65536 -Confirm:$false
   
   # Create and format B: drive (Backup) if configured
   New-Partition -DiskNumber 4 -UseMaximumSize -DriveLetter B | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL_Backup" -AllocationUnitSize 65536 -Confirm:$false
   ```

2. **Install SQL Server**
   - Use the formatted drives during installation
   - Data files: D:\SQLData
   - Log files: E:\SQLLogs
   - TempDB: T:\TempDB

3. **Configure SQL Server Settings**
   ```sql
   -- Set max server memory (leave ~4GB for OS)
   EXEC sp_configure 'show advanced options', 1;
   RECONFIGURE;
   EXEC sp_configure 'max server memory', 28672; -- For 32GB VM
   RECONFIGURE;
   
   -- Configure TempDB (one file per core, up to 8 files)
   -- Adjust based on your CPU count
   ```

4. **Apply Windows and SQL Server Updates**

5. **Configure SQL Server backup strategy**

## Variables Reference

### Required Variables
- `vsphere_user` - vSphere username
- `vsphere_password` - vSphere password
- `datacenter` - vSphere datacenter name
- `datastore` - vSphere datastore name
- `cluster` - vSphere cluster name
- `network` - vSphere network name
- `vm_folder` - VM folder path
- `template_name` - Windows template name
- `vm_name` - New VM name
- `hostname` - Computer name
- `admin_password` - Local administrator password
- `ipv4_address` - Static IP address
- `ipv4_gateway` - Default gateway

### Optional Variables
See `variables.tf` for complete list with defaults.

## Sizing Recommendations

### Small Database (< 100GB)
- CPU: 4-8 vCPUs
- Memory: 16-32 GB
- Data Disk: 200 GB
- Log Disk: 100 GB
- TempDB: 50 GB

### Medium Database (100GB - 1TB)
- CPU: 8-16 vCPUs
- Memory: 32-64 GB
- Data Disk: 500-1000 GB
- Log Disk: 200-500 GB
- TempDB: 100-200 GB

### Large Database (> 1TB)
- CPU: 16-32 vCPUs
- Memory: 64-128+ GB
- Data Disk: 1TB+
- Log Disk: 500GB+
- TempDB: 200GB+

## Troubleshooting

### VM Customization Fails
- Ensure VMware Tools is installed in the template
- Verify the template has been sysprep'd
- Check network connectivity

### Disk Performance Issues
- Verify PVSCSI controller is in use
- Ensure eager zeroed thick provisioning for production
- Check datastore performance

### Memory Issues
- Ensure memory reservation is enabled for production
- Verify ESXi host has sufficient memory

## Additional Resources

- [VMware SQL Server Best Practices](https://core.vmware.com/resource/sql-server-vmware-vsphere)
- [Microsoft SQL Server on vSphere](https://docs.microsoft.com/en-us/sql/sql-server/)
- [Terraform vSphere Provider Documentation](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)

## License

This Terraform configuration is provided as-is for use within your organization.
