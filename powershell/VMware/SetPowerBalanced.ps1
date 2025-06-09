Connect-VIServer 

(Get-View (Get-VMHost | Get-View).ConfigManager.PowerSystem).ConfigurePowerPolicy(2)

Disconnect-VIServer