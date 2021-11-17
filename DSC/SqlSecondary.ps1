Configuration SqlSecondary
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

  # Credential store
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

  Node SQL02
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
      Name       = 'SQL02'
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
    xWaitForCluster 'WaitForCluster'
    {
      Name             = 'SqlCluster'
      RetryIntervalSec = 10
      RetryCount       = 60
      DependsOn        = '[xWindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
    }

    Script 'JoinExistingCluster'
    {
      GetScript = { 
          return @{ 'Result' = $true }
      }
      SetScript = {
          # $targetNodeName = $env:COMPUTERNAME
          Add-ClusterNode -Name 'SQL02' -Cluster 'SQL01'
      }
      TestScript = {
          # $targetNodeName = $env:COMPUTERNAME
          $(Get-ClusterNode -Cluster 'SQL01').Name -contains 'SQL02'
      }
      DependsOn = "[xWaitForCluster]WaitForCluster"
      PsDscRunAsCredential = $cred_adjoin
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
      InstanceName          = 'INSTANCE2'
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
      InstanceName           = 'INSTANCE2'
      ProtocolName           = 'TcpIp'
      Enabled                = $true
      ListenOnAllIpAddresses = $true
      KeepAlive              = 20000
    }

    SqlConfiguration 'AllowRemoteAccess'
    {
      DependsOn      ='[SqlSetup]DB'
      InstanceName   = 'INSTANCE2'
      OptionName     = 'remote access'
      OptionValue    = 1
      RestartService = $true
    }

    SqlWindowsFirewall 'AllowFirewall'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'INSTANCE2'
      Features              = 'SQLEngine'
      SourcePath            = 'C:\Packages\SQL2019'
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
      InstanceName         = 'INSTANCE1'
      RetryIntervalSec     = 60
      RetryCount           = 40
      ServerName           = 'SQL01'
      PsDscRunAsCredential = $cred_adadmin
    }

    SqlAGReplica 'AddReplica'
    {
      Ensure                     = 'Present'
      Name                       = 'SQL02\INSTANCE2'
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