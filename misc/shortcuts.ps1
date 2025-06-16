## Get Domain and ESXi OOB mgmt details
$DomainName = read-host -Prompt "Please provide the domain name of your ESXi hosts."
Write-host "Please provide the URL modifier for OOB, iDRAC, iLO, IPMI." -ForegroundColor Yellow
Write-host "Example:"-ForegroundColor Yellow
Write-Host "ESXi: esxihost1.domain.com"-ForegroundColor Yellow
Write-host "ESXi iDrac: esxihost1-drac.domain.com"-ForegroundColor Yellow
Write-Host "User would enter 'drac'." -ForegroundColor Yellow
$OOBManagerURLModifier = Read-Host -Prompt "Please provide the URL modifier for OOB, iDRAC, iLO, IPMI."

$OutFilePath = Read-Host -Prompt "Please provide the path where you would like the bookmarks file to be saved."

# Get a list of clusters
$clusters = Get-Cluster | sort name, uid
$esxihosts = Get-VMHost | sort Parent, name | select Parent, name

# Create simplified hash table to speed up 'get-view' command for determining which VMware VMs exist in environment.
$hshGetViewParams = @{
    ViewType = "VirtualMachine"
    Property = "Name", "Config.VAppConfig.Product"
}
$vms = get-view @hshGetViewParams

# Create an empty string to store the bookmarks HTML code
$html = $folderHtml = $bookmarkHtml = ""

$html += "<DT>`n<H3 FOLDED>vSphere Infra.</H3>`n<DL>`n"
$html += "<DT>`n<H3 FOLDED>vSphere Client</H3>`n<DL>`n"
## Recommend using FQDN with connect-viserver command.
##vCenter UI URLS.
foreach ($vcenter in ($global:DefaultVIServers.name | sort )) {
    $bookmarkHtml = "<DT><A HREF=""https://$vcenter`/ui"">$vcenter - H5</A></DT>`n"
    $Html += $bookmarkHtml
}
$html += "</DL>`n</DT>`n"
##vCenter VAMI URLS
$html += "<DT>`n<H3 FOLDED>vCenter Server Appliance Management Interface - VAMI</H3>`n<DL>`n"
foreach ($vcenter in ($global:DefaultVIServers.name | sort )) {
    $bookmarkHtml = "<DT><A HREF=""https://$vcenter`:5480"">$vcenter - VAMI</A></DT>`n"
    $Html += $bookmarkHtml

}
$html += "</DL>`n</DT>`n"
##vCenter MOB URLS
$html += "<DT>`n<H3 FOLDED>vCenter Managed Object Browser - MOB</H3>`n<DL>`n"
foreach ($vcenter in ($global:DefaultVIServers.name | sort )) {
    $bookmarkHtml = "<DT><A HREF=""https://$vcenter`/mob"">$vcenter - MOB</A></DT>`n"
    $html += $bookmarkHtml

}
$html += "</DL>`n</DT>`n"
##vCenter API Explorer URLS
$html += "<DT>`n<H3 FOLDED>vCenter Client - API Explorer</H3>`n<DL>`n"
foreach ($vcenter in ($global:DefaultVIServers.name | sort )) {
    $bookmarkHtml = "<DT><A HREF=""https://$vcenter`/apiexplorer"">$vcenter - API Explorer</A></DT>`n"
    $html += $bookmarkHtml

}
$html += "</DL>`n</DT>`n"
##Other VMware Products found in environment.
##VMware Identity Manager
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "IdentityManager"}){
    $html += "<DT>`n<H3 FOLDED>VMware Identity Manager</H3>`n<DL>`n"
    foreach($VMwareIdentityManager in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "IdentityManager"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareIdentityManager"">$VMwareIdentityManager</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware Aria Operations for Networks Platform
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "VMware Aria Operations for Networks Platform"}){
    $html += "<DT>`n<H3 FOLDED>VMware Aria Operations for Networks Platform</H3>`n<DL>`n"
    foreach($VMwareAriaOperationsforNetworksPlatform in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "VMware Aria Operations for Networks Platform"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareAriaOperationsforNetworksPlatform"">$VMwareAriaOperationsforNetworksPlatform</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware Aria Suite Lifecycle Appliance
if ($vms |where {($_.Config.VAppConfig.Product.Name -eq "VMware Aria Suite Lifecycle Appliance") -or ($_.Config.VAppConfig.Product.Name -eq "VMware vRealize Suite Life Cycle Manager Appliance")}){
    $html += "<DT>`n<H3 FOLDED>VMware Aria Suite Lifecycle Appliance</H3>`n<DL>`n"
    foreach($VMwareAriaSuiteLifecycleAppliance in ($vms | where {($_.Config.VAppConfig.Product.Name -eq "VMware Aria Suite Lifecycle Appliance") -or ($_.Config.VAppConfig.Product.Name -eq "VMware vRealize Suite Life Cycle Manager Appliance")} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareAriaSuiteLifecycleAppliance`/login"">$VMwareAriaSuiteLifecycleAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware HCX
if ($vms |where {$_.Config.VAppConfig.Product.Name -like "*HCX*"}){
    $html += "<DT>`n<H3 FOLDED>VMware HCX</H3>`n<DL>`n"
    foreach($VMwareHCXAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -like "*HCX*"} | sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareHCXAppliance"">$VMwareHCXAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}


##VMware NSX
if ($vms |where {$_.Config.VAppConfig.Product.Name -like "*NSX*"}){
    $html += "<DT>`n<H3 FOLDED>VMware NSX</H3>`n<DL>`n"
    foreach($VMwareNSXAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -like "*NSX*"} | sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareNSXAppliance"">$VMwareNSXAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware Site Recovery Manager Appliance
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "VMware Site Recovery Manager Appliance"}){
    $html += "<DT>`n<H3 FOLDED>VMware Site Recovery Manager Appliance</H3>`n<DL>`n"
    foreach($VMwareSiteRecoveryManagerAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "VMware Site Recovery Manager Appliance"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareSiteRecoveryManagerAppliance`/dr"">$VMwareSiteRecoveryManagerAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware Skyline Appliance
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "VMware Skyline Appliance"}){
    $html += "<DT>`n<H3 FOLDED>VMware Skyline Appliance</H3>`n<DL>`n"
    foreach($VMwareSkylineAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "VMware Skyline Appliance"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareSkylineAppliance`/login"">$VMwareSkylineAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##VMware vCenter Log Insight
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "VMware vCenter Log Insight"}){
    $html += "<DT>`n<H3 FOLDED>VMware vCenter Log Insight</H3>`n<DL>`n"
    foreach($VMwarevCenterLogInsight in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "VMware vCenter Log Insight"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwarevCenterLogInsight`/login"">$VMwarevCenterLogInsight</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##vRealize Automation
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "vRealize Automation"}){
    $html += "<DT>`n<H3 FOLDED>vRealize Automation</H3>`n<DL>`n"
    foreach($VMwareAriaAutomation in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "vRealize Automation"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$VMwareAriaAutomation"">$VMwareAriaAutomation</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##vRealize Operations Appliance
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "vRealize Operations Appliance"}){
    $html += "<DT>`n<H3 FOLDED>vRealize Operations Appliance</H3>`n<DL>`n"
    foreach($vRealizeOperationsAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "vRealize Operations Appliance"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$vRealizeOperationsAppliance"">$vRealizeOperationsAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    $html += "</DL>`n</DT>`n"
}

##vSphere Replication Manager Appliance
if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "vSphere Replication Appliance"}){
    $html += "<DT>`n<H3 FOLDED>vSphere Replication Manager Appliance</H3>`n<DL>`n"
    foreach($vSphereReplicationAppliance in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "vSphere Replication Appliance"} |sort name | select -ExpandProperty name)) {
        $bookmarkHtml = "<DT><A HREF=""https://$vSphereReplicationAppliance`:5480"">$vSphereReplicationAppliance</A></DT>`n"
        $html += $bookmarkHtml
    }
    if ($vms |where {$_.Config.VAppConfig.Product.Name -eq "vSphere Replication Server"}){
        $html += "<DT>`n<H3 FOLDED>vSphere Replication Support Server</H3>`n<DL>`n"
        foreach($vSphereReplicationServer in ($vms | where {$_.Config.VAppConfig.Product.Name -eq "vSphere Replication Server"} |sort name | select -ExpandProperty name)) {
            $bookmarkHtml = "<DT><A HREF=""https://$vSphereReplicationServer`:5480"">$vSphereReplicationServer</A></DT>`n"
            $html += $bookmarkHtml
        }
        $html += "</DL>`n</DT>`n"
    }
    $html += "</DL>`n</DT>`n"
}

$html += "</DL>`n</DT>`n"
##ESXI Section ##
$html += "<DT>`n<H3 FOLDED>ESXi Hosts</H3>`n<DL>`n"
$html += "<DT>`n<H3 FOLDED>ESXi Client</H3>`n<DL>`n"
foreach ($vcenter in ($global:DefaultVIServers.name | sort)) {
    $html += "<DT>`n<H3 FOLDED>$vcenter</H3>`n<DL>`n"
    foreach ($cluster in ($clusters | where { $_.uid -like "*$vcenter*" })) {
        # Get the cluster name
        $clusterName = $cluster.Name

        # Generate the folder HTML code
        $folderHtml = "<DT>`n<H3 FOLDED>$clusterName</H3>`n<DL>`n"

        # Loop through the ESXi hosts in the cluster and generate a bookmark for each one
        foreach ($esxiHost in ($esxihosts | where { $_.Parent -eq $cluster } | select name)) {
            # Get the ESXi host name
            $hostName = $esxiHost.Name

            # Generate the bookmark HTML code
            $bookmarkHtml = "<DT><A HREF=""https://$hostName"">$hostName</A></DT>`n"

            # Add the bookmark HTML code to the folder HTML code
            $folderHtml += $bookmarkHtml
        }

        # Close the folder HTML code
        $folderHtml += "</DL>`n</DT>`n"

        # Add the folder HTML code to the string
        $html += $folderHtml
    }
    # Close the folder HTML code
    $html += "</DL>`n</DT>`n"
}
$html += "</DL>`n</DT>`n"
$html += "<DT>`n<H3 FOLDED>ESXi iDrac</H3>`n<DL>`n"
foreach ($vcenter in ($global:DefaultVIServers.name | sort)) {
    $html += "<DT>`n<H3 FOLDED>$vcenter</H3>`n<DL>`n"
    # Loop through the clusters and generate a folder for each one
    foreach ($cluster in ($clusters | where { $_.uid -like "*$vcenter*" })) {
        # Get the cluster name
        $clusterName = $cluster.Name

        # Generate the folder HTML code
        $folderHtml = "<DT>`n<H3 FOLDED>$clusterName</H3>`n<DL>`n"

        # Loop through the ESXi hosts in the cluster and generate a bookmark for each one
        foreach ($esxiHost in ($esxihosts | where { $_.Parent -eq $cluster } | select name)) {
            # Get the ESXi host name
            $hostName = $esxiHost.Name
            $ESXiOOBName = $esxiHost.Name.Replace(".$DomainName", "-$OOBManagerURLModifier.$DomainName")

            # Generate the bookmark HTML code
            $bookmarkHtml = "<DT><A HREF=""https://$ESXiOOBName"">$ESXiOOBName</A></DT>`n"

            # Add the bookmark HTML code to the folder HTML code
            $folderHtml += $bookmarkHtml
        }

        # Close the folder HTML code
        $folderHtml += "</DL>`n</DT>`n"

        # Add the folder HTML code to the string
        $html += $folderHtml
    }
    $html += "</DL>`n</DT>`n"
}
$html += "</DL>`n</DT>`n"
## End of ESXI Section ##
# Create the HTML file with the bookmarks
$html | Out-File -FilePath "$OutFilePath`\scriptedbookmarks.html" -Encoding UTF8