Configuration SqlSecondary_AlwaysOn
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName SqlServerDsc

  # Credential AD Admin
  $cred_adadmin = Get-AutomationPSCredential 'cred_adadmin'

  Node SQL02
  {
    SqlEndpoint 'HADREndpoint'
    {
      EndPointName         = 'HADR'
      Ensure               = 'Present'
      EndpointType         = 'DatabaseMirroring'
      Port                 = 5022
      ServerName           = 'SQL02'
      InstanceName         = 'INSTANCE2'
      PsDscRunAsCredential = $cred_adadmin
    }

    SqlAlwaysOnService 'EnableAlwaysOn'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL02'
      InstanceName         = 'INSTANCE2'
      RestartTimeout       = 120
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlEndpoint]HADREndpoint'
    }

    SqlWaitForAG 'SQLConfigureAG-WaitAG'
    {
      Name                 = 'AG'
      InstanceName         = 'INSTANCE2'
      RetryIntervalSec     = 30
      RetryCount           = 40
      PsDscRunAsCredential = $cred_adadmin
    }

    SqlAGReplica 'AddReplica'
    {
      Ensure                     = 'Present'
      Name                       = 'SQL02'
      AvailabilityGroupName      = 'AG'
      ServerName                 = 'SQL02'
      InstanceName               = 'INSTANCE2'
      PrimaryReplicaServerName   = 'SQL01'
      PrimaryReplicaInstanceName = 'INSTANCE1'
      ProcessOnlyOnActiveNode    = $true
      AvailabilityMode           = 'SynchronousCommit'
      FailoverMode               = 'Automatic'
      PsDscRunAsCredential       = $cred_adadmin
      DependsOn                  = '[SqlWaitForAG]SQLConfigureAG-WaitAG'
    }
  }
}