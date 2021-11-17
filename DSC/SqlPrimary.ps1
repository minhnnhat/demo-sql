Configuration SqlPrimary
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName SqlServerDsc
  Import-DscResource -Module ComputerManagementDsc -ModuleVersion 8.4.0
  Import-DscResource -Module NetworkingDsc -ModuleVersion 8.2.0
  Import-DscResource -ModuleName xFailOverCluster -ModuleVersion 1.16.0
  Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 6.0.1

  # Credential Store
  $store = Get-AutomationPSCredential 'cred_store'
  $cred_admin = Get-AutomationPSCredential 'cred_admin'
  # Credential SA Sql
  $cred_sasql = Get-AutomationPSCredential 'cred_sql'
  # Credential AD Admin
  $cred_adadmin = Get-AutomationPSCredential 'cred_adadmin'
  $user_ad = 'ntglab\' + $cred_adadmin.UserName
  $pass_ad = ConvertTo-SecureString $cred_adadmin.GetNetworkCredential().Password -AsPlainText -Force
  $cred_adjoin = New-Object System.Management.Automation.PSCredential ($user_ad,$pass_ad)
  # Credential SvcA Sql
  $cred_svcsql = Get-AutomationPSCredential 'cred_svcsql'
  $user_sql = 'ntglab\' + $cred_svcsql.UserName
  $pass_sql = ConvertTo-SecureString $cred_svcsql.GetNetworkCredential().Password -AsPlainText -Force
  $cred_svcasql = New-Object System.Management.Automation.PSCredential ($user_sql,$pass_sql)
  # $SqlSvcCred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $SqlSvcAccount,$cred_svcsql01.Password

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
        Profile     = ('Domain', 'Private', 'Public')
    }

    DnsServerAddress 'DnsServerAddress'
    {
      Address        = '10.0.1.4'
      InterfaceAlias = 'Ethernet'
      AddressFamily  = 'IPv4'
      Validate       = $true
      
    }

    WaitForADDomain 'WaitDomain'
    {
      DomainName    = 'ntglab.com'
      WaitTimeout   = 600
      RestartCount  = 2
      Credential    = $cred_admin
    }

    Computer 'JoinDomain'
    {
      Name       = 'SQL01'
      DomainName = 'ntglab.com'
      Credential = $cred_adjoin
      DependsOn  = '[WaitForADDomain]WaitDomain'
    }

    xGroup 'AddUsertoLocalAdmin'
    {
      GroupName         = 'Administrators'
      Ensure            = 'Present'
      MembersToInclude  = ($user_ad, $user_sql)
      Credential        = $cred_adadmin
      DependsOn         = '[Computer]JoinDomain'
    }
#------------------
# Failover Cluster
#------------------
    xCluster 'CreateCluster' 
    {
      Name                          = 'SqlCluster'
      StaticIPAddress               = '10.0.1.8'
      DomainAdministratorCredential = $cred_adjoin
      DependsOn                     = '[xWindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature', '[Computer]JoinDomain'
    }

    Script  'AddProbeToFailoverClusterResource'
    {
      GetScript  = {
        return @{ 'Result' = $(Get-ClusterResource "Cluster IP Address" | Get-ClusterParameter -Name ProbePort ).Value} 
      }                    
      SetScript  = {
        $Resource = Get-ClusterResource "Cluster IP Address"
        Get-ClusterResource "Cluster IP Address"| Set-ClusterParameter -Multiple @{"Address"="10.0.1.8";"ProbePort"=58888;"SubnetMask"="255.255.255.0";"Network"="Cluster Network 1";"EnableDhcp"=0}
        Stop-ClusterResource $Resource
        Start-ClusterResource 'Cluster Name'
      }
      TestScript = {
        return($(Get-ClusterResource -name "Cluster IP Address" | Get-ClusterParameter -Name ProbePort ).Value -eq 58888)
      }
      PsDscRunAsCredential = $cred_adjoin
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
      Path        = "\\ntglabdevdata.file.core.windows.net\sqlsources\SQL2019.zip"
      Destination = "C:\Packages"
      Credential  = $store
    }

#------------------
# Setup SQL Server
#------------------
    SqlSetup 'DB'
    {
      InstanceName          = 'INSTANCE1'
      SourcePath            = 'C:\Packages\SQL2019'
      Features              = 'SQLENGINE,FullText,Replication'
      SQLCollation          = 'SQL_Latin1_General_CP1_CI_AS'

      SQLSvcAccount         = $cred_svcasql
      AgtSvcAccount         = $cred_svcasql
      SQLSysAdminAccounts   = 'ntglab.com\admin', $cred_adadmin.UserName
      
      InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
      InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
      InstanceDir           = 'C:\Program Files\Microsoft SQL Server'

      SecurityMode          = 'SQL'
      SAPwd                 = $cred_sasql
      #SQLSvcAccount         = $SqlSvcCred

      InstallSQLDataDir     = 'C:\MSSQL\Data'
      SQLUserDBDir          = 'C:\MSSQL\Data'
      SQLUserDBLogDir       = 'C:\MSSQL\Log'
      SQLTempDBDir          = 'C:\MSSQL\Temp'
      SQLTempDBLogDir       = 'C:\MSSQL\Temp'
      SQLBackupDir          = 'C:\MSSQL\Backup'

      UpdateEnabled         = 'False'
      SQLSvcStartupType     = 'Automatic'
      PsDscRunAsCredential  = $cred_adadmin
      DependsOn             = '[xArchive]GetSource'
    }

    SqlProtocol 'ChangeTcpIpOnDefaultInstance'
    {
      DependsOn              = '[SqlSetup]DB'
      InstanceName           = 'INSTANCE1'
      ProtocolName           = 'TcpIp'
      Enabled                = $true
      ListenOnAllIpAddresses = $true
      KeepAlive              = 20000
    }

    SqlConfiguration 'AllowRemoteAccess'
    {
      DependsOn      ='[SqlSetup]DB'
      InstanceName   = 'INSTANCE1'
      OptionName     = 'remote access'
      OptionValue    = 1
      RestartService = $true
    }

    SqlWindowsFirewall 'AllowFirewall'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'INSTANCE1'
      Features              = 'SQLENGINE'
      SourcePath            = 'C:\Packages\SQL2019'
    }

    SqlDatabase 'CreateDbaDatabase'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'INSTANCE1'
      Name                  = 'SyncedDB'
      Collation             = 'SQL_Latin1_General_100_CS_AS'
    }

    # Adding the required service account to allow the cluster to log into SQL
    SqlLogin 'AddWindowsUserSqlSvc'
    {
      Ensure               = 'Present'
      Name                 = $user_sql
      LoginType            = 'WindowsUser'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlSetup]DB'
    }

    SqlLogin 'AddWindowsUserClusSvc'
    {
      Ensure               = 'Present'
      Name                 = 'NT SERVICE\ClusSvc'
      LoginType            = 'WindowsUser'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlSetup]DB'
    }

    # Add the required permissions to the cluster service login
    SqlPermission 'SQLConfigureServerPermissionSYSTEMSvc'
    {       
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      Principal            = $user_sql
      Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState', 'AlterAnyEndPoint', 'ConnectSql'
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlLogin]AddWindowsUserSqlSvc'
    }

    SqlPermission 'AddNTServiceClusSvcPermissions'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL01'
      InstanceName         = 'INSTANCE1'
      Principal            = 'NT SERVICE\ClusSvc'
      Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState'
      PsDscRunAsCredential = $cred_adadmin
      DependsOn            = '[SqlLogin]AddWindowsUserClusSvc'
    }

    # SqlMaxDop 'Set_SqlMaxDop_ToAuto'
    # {
    #   Ensure                  = 'Present'
    #   DynamicAlloc            = $true
    #   ServerName              = 'SQL01'
    #   InstanceName            = 'INSTANCE1'
    #   PsDscRunAsCredential    = (Get-AutomationPSCredential 'cred_adadmin')
    #   DependsOn               = '[SqlSetup]DB'
    # }

    # SqlMemory 'Set_SQLServerMaxMemory_ToAuto'
    # {
    #   Ensure               = 'Present'
    #   DynamicAlloc         = $true
    #   ServerName           = 'SQL01'
    #   InstanceName         = 'INSTANCE1'
    #   PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_adadmin')
    #   DependsOn            = '[SqlSetup]DB'
    # }

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

    SqlAGDatabase 'AddAGDatabaseMemberships'
    {
      AvailabilityGroupName   = 'AG'
      BackupPath              = '\\SQL01\Backup'
      DatabaseName            = 'SyncedDB'
      InstanceName            = 'INSTANCE1'
      ServerName              = 'SQL01'
      Ensure                  = 'Present'
      ProcessOnlyOnActiveNode = $true
      PsDscRunAsCredential    = $cred_adadmin
    }
  }
}