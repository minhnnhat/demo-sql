
Configuration SqlPrimary
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName SqlServerDsc
  Import-DscResource -Module ComputerManagementDsc -ModuleVersion 8.4.0
  Import-DscResource -Module NetworkingDsc -ModuleVersion 8.2.0
  Import-DscResource -ModuleName xFailOverCluster -ModuleVersion 1.15.0
  Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 6.0.1

  $store = Get-AutomationPSCredential 'cred_store'
  $cred_adadmin = Get-AutomationPSCredential 'cred_adadmin'
  $cred_adjoin = new-object -typename System.Management.Automation.PSCredential -argumentlist ('ntglab\' + $cred_adadmin.UserName, $cred_adadmin.Password)
  $cred_svcsql01 = Get-AutomationPSCredential 'cred_svcsql01'
  $SqlSvcAccount = ('ntglab\' + $cred_svcsql01.UserName + '$')
  $SqlSvcCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SqlSvcAccount,$cred_svcsql01.Password

  Node SQL01
  {
#-----------------
# Enable Features
#-----------------
    xWindowsFeature 'AddFailoverClusterFeature'
    {
      Ensure               = 'Present'
      Name                 = 'Failover-Clustering'
      IncludeAllSubFeature = $IncludeAllSubFeature
    }

    xWindowsFeature 'AddFailoverClusterTools'
    {
        Ensure = "Present"
        Name   = "RSAT-Clustering-Mgmt"
    }

    xWindowsFeature 'AddRemoteServerAdministrationToolsClusteringPowerShellFeature' 
    {
      Ensure               = 'Present'
      Name                 = 'RSAT-Clustering-PowerShell'
      IncludeAllSubFeature = $IncludeAllSubFeature
      DependsOn            = '[xWindowsFeature]AddFailoverClusterFeature'
    }

    xWindowsFeature 'AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature' 
    {
      Ensure               = 'Present'
      Name                 = 'RSAT-Clustering-CmdInterface'
      IncludeAllSubFeature = $IncludeAllSubFeature
      DependsOn            = '[xWindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
    }

    xWindowsFeature 'ADPS'
    {
      Name = "RSAT-AD-PowerShell"
      Ensure = "Present"
    }

    xWindowsFeature 'NetFramework'
    {
      Name   = 'NET-Framework-45-Core'
      Ensure = 'Present'
    }
#-------------
# Join Domain
#-------------
    Firewall 'AllowFirewallTCP'
    {
        Name        = 'AllowTCP'
        DisplayName = 'Allow (TCP-in)'
        Ensure      = 'Present'
        Enabled     = 'True'
        Direction   = 'Inbound'
        LocalPort   = ('1433', '5022', '59999', '58888')
        Protocol    = 'TCP'
        Profile     = ('Domain', 'Private')
    }

    DnsServerAddress 'DnsServerAddress'
    {
      Address        = '10.0.1.4'
      InterfaceAlias = 'Ethernet 2'
      AddressFamily  = 'IPv4'
      Validate       = $true
      
    }

    WaitForADDomain 'WaitDomain'
    {
      DomainName    = 'ntglab.com'
      WaitTimeout   = 600
      RestartCount  = 2
      Credential    = (Get-AutomationPSCredential 'cred_admin')
    }

    Computer 'JoinDomain'
    {
      Name       = 'SQL01'
      DomainName = 'ntglab.com'
      Credential = (Get-AutomationPSCredential 'cred_admin')
      DependsOn  = '[DnsServerAddress]DnsServerAddress'
    }

    xGroup 'AddUsertoLocalAdmin'
    {
      GroupName         = 'Administrators'
      Ensure            = 'Present'
      MembersToInclude  = ($cred_adadmin.UserName, $cred_svcsql01.UserName)
      Credential        = $cred_adadmin
      DependsOn         = '[Computer]JoinDomain'
    }

    # xGroup 'AddSvcSql01toLocalAdmin'
    # {
    #   GroupName         = 'Administrators'
    #   Ensure            = 'Present'
    #   MembersToInclude  = $cred_svcsql01.UserName
    #   Credential        = $cred_adadmin
    #   DependsOn         = '[Computer]JoinDomain'
    # }
#------------------
# Failover Cluster
#------------------
    xCluster 'CreateCluster' 
    {
      Name                          = 'SqlCluster'
      StaticIPAddress               = '10.0.1.10'
      DomainAdministratorCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn                     = '[xWindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature', '[Computer]JoinDomain'
    }

    Script  'AddProbeToFailoverClusterResource'
    {
      GetScript  = {
        return @{ 'Result' = $(Get-ClusterResource "Cluster IP Address" | Get-ClusterParameter -Name ProbePort ).Value} 
      }                    
      SetScript  = {
        $Resource = Get-ClusterResource "Cluster IP Address"
        Get-ClusterResource "Cluster IP Address"| Set-ClusterParameter -Multiple @{"Address"="10.0.1.10";"ProbePort"=59999;"SubnetMask"="255.255.255.0";"Network"="Cluster Network 1";"EnableDhcp"=0}
        Stop-ClusterResource $Resource
        Start-ClusterResource 'Cluster Name'
      }
      TestScript = {
        return($(Get-ClusterResource -name "Cluster IP Address" | Get-ClusterParameter -Name ProbePort ).Value -eq 59999)
      }
      PsDscRunAsCredential = $cred_adadmin
      DependsON = "[xCluster]CreateCluster"
    }

    xClusterQuorum 'SetQuorumToNodeAndCloudMajorityConfig' 
    {
      IsSingleInstance        = 'Yes'
      Type                    = 'NodeAndCloudMajority'
      Resource                = $store.UserName
      StorageAccountAccessKey = $store.GetNetworkCredential().Password
      DependsOn               = '[xCluster]CreateCluster'
    }

    xArchive 'GetSource'
    {
      Ensure      = "Present"
      Path        = "\\ntglabdevdata.file.core.windows.net\sqlsources\SQL2017.zip"
      Destination = "C:\Packages"
      Credential  = (Get-AutomationPSCredential 'cred_store')
    }

#------------------
# Setup SQL Server
#------------------
    SqlSetup 'DB'
    {
      InstanceName          = 'MSSQLSERVER'
      SourcePath            = 'C:\Packages\SQL2017'
      Features              = 'SQLENGINE,FullText,Replication'
      
      InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
      InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
      InstanceDir           = 'C:\Program Files\Microsoft SQL Server'

      SecurityMode          = 'SQL'
      SAPwd                 = (Get-AutomationPSCredential 'cred_sql')
      SQLSysAdminAccounts   = $cred_adadmin.UserName
      SQLSvcAccount         = $SqlSvcCred

      InstallSQLDataDir     = 'C:\MSSQL\Data'
      SQLUserDBDir          = 'C:\MSSQL\Data'
      SQLUserDBLogDir       = 'C:\MSSQL\Log'
      SQLTempDBDir          = 'C:\MSSQL\Temp'
      SQLTempDBLogDir       = 'C:\MSSQL\Temp'
      SQLBackupDir          = 'C:\MSSQL\Backup'

      UpdateEnabled         = 'False'
      SQLSvcStartupType     = 'Automatic'
      PsDscRunAsCredential  = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn             = '[xArchive]GetSource'
    }

    SqlProtocol 'ChangeTcpIpOnDefaultInstance'
    {
      DependsOn              = '[SqlSetup]DB'
      InstanceName           = 'MSSQLSERVER'
      ProtocolName           = 'TcpIp'
      Enabled                = $true
      ListenOnAllIpAddresses = $true
      KeepAlive              = 20000
    }

    SqlConfiguration 'AllowRemoteAccess'
    {
      DependsOn      ='[SqlSetup]DB'
      InstanceName   = 'MSSQLSERVER'
      OptionName     = 'remote access'
      OptionValue    = 1
      RestartService = $true
    }

    SqlWindowsFirewall 'AllowFirewall'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'MSSQLSERVER'
      Features              = 'SQLEngine'
      SourcePath            = 'C:\Packages\SQL2017'
    }

    # SqlDatabase 'CreateDbaDatabase'
    # {
    #   DependsOn             = '[SqlSetup]DB'
    #   InstanceName          = 'MSSQLSERVER'
    #   Name                  = 'DBA'
    # }

    # Adding the required service account to allow the cluster to log into SQL
    SqlLogin 'AddWindowsUserSqlSvc'
    {
      Ensure               = 'Present'
      Name                 = $SqlSvcAccount
      LoginType            = 'WindowsUser'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlSetup]DB'
    }

    SqlLogin 'AddWindowsUserClusSvc'
    {
      Ensure               = 'Present'
      Name                 = 'NT SERVICE\ClusSvc'
      LoginType            = 'WindowsUser'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlSetup]DB'
    }

    # Add the required permissions to the cluster service login
    SqlPermission 'SQLConfigureServerPermissionSYSTEMSvc'
    {       
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      Principal            = $SqlSvcAccount
      Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'AlterAnyEndPoint', 'ConnectSql'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlLogin]AddWindowsUserSqlSvc'
    }

    SqlPermission 'AddNTServiceClusSvcPermissions'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      Principal            = 'NT SERVICE\ClusSvc'
      Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlLogin]AddWindowsUserClusSvc'
    }

    SqlMaxDop 'Set_SqlMaxDop_ToAuto'
    {
      Ensure                  = 'Present'
      DynamicAlloc            = $true
      ServerName              = 'SQL01'
      InstanceName            = 'MSSQLSERVER'
      PsDscRunAsCredential    = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn               = '[SqlSetup]DB'
    }

    SqlMemory 'Set_SQLServerMaxMemory_ToAuto'
    {
      Ensure               = 'Present'
      DynamicAlloc         = $true
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlSetup]DB'
    }

    SqlEndpoint 'HADREndpoint'
    {
      EndPointName         = 'HADR'
      Ensure               = 'Present'
      EndpointType         = 'DatabaseMirroring'
      Port                 = 5022
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlSetup]DB', '[xCluster]CreateCluster'
    }

    SqlAlwaysOnService 'EnableAlwaysOn'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      RestartTimeout       = 120
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsOn            = '[SqlEndpoint]HADREndpoint'
    }

    SqlAG 'AddAG'
    {
      Ensure               = 'Present'
      Name                 = 'TestAG'
      InstanceName         = 'MSSQLSERVER'
      ServerName           = 'SQL01'
      AvailabilityMode     = 'SynchronousCommit'
      FailoverMode         = 'Automatic'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')  
      DependsOn            = '[SqlAlwaysOnService]EnableAlwaysOn', '[SqlEndpoint]HADREndpoint', '[SqlPermission]AddNTServiceClusSvcPermissions'
    }

    SqlAGListener 'AvailabilityGroupListener'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'MSSQLSERVER'
      AvailabilityGroup    = 'TestAG'
      Name                 = 'TestAG'
      IpAddress            = '10.0.1.9/255.255.255.0'
      Port                 = '1433'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
      DependsON            = '[SqlAG]AddAG'
    }

    Script  'AddProbeToSQLClusterResource'
    {
      GetScript  = {
        return @{ 'Result' = $(Get-ClusterResource 'TestAG_10.0.1.9' | Get-ClusterParameter -Name ProbePort ).Value}
      }                    
      SetScript  = { 
        Get-ClusterResource 'TestAG_10.0.1.9'| Set-ClusterParameter -Multiple @{"Address"="10.0.1.9";"ProbePort"=59999;"SubnetMask"="255.255.255.0";"Network"="Cluster Network 1";"EnableDhcp"=0}
      }
      TestScript = {
        return($(Get-ClusterResource 'TestAG_10.0.1.9' | Get-ClusterParameter -Name ProbePort ).Value -eq 59999)
      }
      PsDscRunAsCredential = $cred_adadmin
      DependsON = "[SqlAGListener]AvailabilityGroupListener"
    }
  }
}