Connect-VIServer -Server 

(Get-View (Get-VMHost | Get-View).ConfigManager.PowerSystem).ConfigurePowerPolicy(3)

Disconnect-VIServer