Configuration SqlPrimary_AlwaysOn
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName SqlServerDsc

  # Credential AD Admin
  $cred_adadmin = Get-AutomationPSCredential 'cred_adadmin'

  Node SQL01
  {
    SqlEndpoint 'HADREndpoint'
    {
      EndPointName         = 'HADR'
      Ensure               = 'Present'
      EndpointType         = 'DatabaseMirroring'
      Port                 = 5022
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      PsDscRunAsCredential = $cred_adadmin
    }

    SqlAlwaysOnService 'EnableAlwaysOn'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      RestartTimeout       = 120
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlEndpoint]HADREndpoint'
    }

    SqlAG 'AddAG'
    {
      Ensure               = 'Present'
      Name                 = 'AG'
      InstanceName         = 'INSTANCE1'
      ServerName           = 'SQL01'
      AvailabilityMode     = 'SynchronousCommit'
      FailoverMode         = 'Automatic'
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlAlwaysOnService]EnableAlwaysOn', '[SqlEndpoint]HADREndpoint'
    }

    SqlAGListener 'AvailabilityGroupListener'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      AvailabilityGroup    = 'AG'
      Name                 = 'AG'
      IpAddress            = '10.0.1.9/255.255.255.0'
      Port                 = '1433'
      PsDscRunAsCredential = $cred_adadmin
      DependsON            = '[SqlAG]AddAG'
    }

    Script  'AddProbeToSQLClusterResource'
    {
      GetScript  = {
        return @{ 'Result' = $(Get-ClusterResource 'AG_10.0.1.9' | Get-ClusterParameter -Name ProbePort ).Value}
      }                    
      SetScript  = { 
        Get-ClusterResource 'AG_10.0.1.9'| Set-ClusterParameter -Multiple @{"Address"="10.0.1.9";"ProbePort"=59999;"SubnetMask"="255.255.255.0";"Network"="Cluster Network 1";"EnableDhcp"=0}
      }
      TestScript = {
        return($(Get-ClusterResource 'AG_10.0.1.9' | Get-ClusterParameter -Name ProbePort ).Value -eq 59999)
      }
      PsDscRunAsCredential = $cred_adadmin
      DependsON = "[SqlAGListener]AvailabilityGroupListener"
    }
  }
}