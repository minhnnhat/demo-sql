Configuration SqlSecondary
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

  $store = Get-AutomationPSCredential -Name 'cred_store'
  $cred = Get-AutomationPSCredential 'cred_admin'

  Node SQL02
  {
#-----------------
# Enable Features
#-----------------
    xWindowsFeature 'AddFailoverFeature'
    {
      Ensure = 'Present'
      Name   = 'Failover-clustering'
    }

    xWindowsFeature 'AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
    {
      Ensure    = 'Present'
      Name      = 'RSAT-Clustering-PowerShell'
      DependsOn = '[xWindowsFeature]AddFailoverFeature'
    }

    xWindowsFeature 'AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
    {
      Ensure    = 'Present'
      Name      = 'RSAT-Clustering-CmdInterface'
      DependsOn = '[xWindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
    }

    xWindowsFeature ADPS
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
        Name                  = 'AllowTCP'
        DisplayName           = 'Allow (TCP-in)'
        Ensure                = 'Present'
        Enabled               = 'True'
        Direction             = 'Inbound'
        LocalPort             = ('1433', '5022', '59999', '58888')
        Protocol              = 'TCP'
        Profile               = ('Domain', 'Private')
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
        DomainName      = 'ntglab.com'
        WaitTimeout     = 600
        RestartCount    = 2
        Credential      = (Get-AutomationPSCredential 'cred_admin')
    }

    Computer 'JoinDomain'
    {
      Name       = 'SQL02'
      DomainName = 'ntglab.com'
      Credential = (Get-AutomationPSCredential 'cred_sqladuser')
      DependsOn  = '[DnsServerAddress]DnsServerAddress'
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
      PsDscRunAsCredential = $cred
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
      DependsOn             = '[xArchive]GetSource'
      InstanceName          = 'MSSQLSERVER'
      SourcePath            = 'C:\Packages\SQL2017'
      Features              = 'SQLENGINE,FullText,Replication'
      InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
      InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
      InstanceDir           = 'C:\Program Files\Microsoft SQL Server'
      SQLSysAdminAccounts   = @('Administrators')
      InstallSQLDataDir     = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SQLUserDBDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SQLUserDBLogDir       = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SQLTempDBDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SQLTempDBLogDir       = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SQLBackupDir          = 'C:\Program Files\Microsoft SQL Server\MSSQL19.MSSQLSERVER\MSSQL\Data'
      SecurityMode          = 'SQL'
      SAPwd                 = (Get-AutomationPSCredential 'cred_sql')
      UpdateEnabled         = $true
      SQLSvcStartupType     = 'Automatic'
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

    SqlLogin 'AddNTServiceClusSvc'
    {
      Ensure               = 'Present'
      Name                 = 'NT SERVICE\ClusSvc'
      LoginType            = 'WindowsUser'
      ServerName           = 'SQL02'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_sqladuser')   
      DependsOn            = '[SqlSetup]DB', '[Script]JoinExistingCluster'
    }

    SqlPermission 'AddNTServiceClusSvcPermissions'
    {       
      Ensure               = 'Present'
      ServerName           = 'SQL02'
      InstanceName         = 'MSSQLSERVER'
      Principal            = 'NT SERVICE\ClusSvc'
      Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_sqladuser')
      DependsOn            = '[SqlLogin]AddNTServiceClusSvc'
    }

    SqlEndpoint 'HADREndpoint'
    {
      EndPointName         = 'HADR'
      Ensure               = 'Present'
      EndpointType         = 'DatabaseMirroring'
      Port                 = 5022
      ServerName           = 'SQL02'
      InstanceName         = 'MSSQLSERVER'
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_sqladuser')
      DependsOn            = '[SqlSetup]DB', '[Script]JoinExistingCluster'
    }

    SqlAlwaysOnService 'EnableAlwaysOn'
    {
      Ensure               = 'Present'
      ServerName           = 'SQL02'
      InstanceName         = 'MSSQLSERVER'
      RestartTimeout       = 120
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_sqladuser')
      DependsOn            = '[SqlSetup]DB', '[Script]JoinExistingCluster'
    }

    SqlWaitForAG 'SQLConfigureAG-WaitAG'
    {
      Name                 = 'TestAG'
      InstanceName         = 'MSSQLSERVER'
      RetryIntervalSec     = 30
      RetryCount           = 40
      PsDscRunAsCredential = (Get-AutomationPSCredential 'cred_sqladuser')
    }

    SqlAGReplica 'AddReplica'
    {
      Ensure                     = 'Present'
      Name                       = 'SQL02'
      AvailabilityGroupName      = 'TestAG'
      ServerName                 = 'SQL02'
      InstanceName               = 'MSSQLSERVER'
      PrimaryReplicaServerName   = 'SQL01'
      PrimaryReplicaInstanceName = 'MSSQLSERVER'
      ProcessOnlyOnActiveNode    = $true
      AvailabilityMode           = 'SynchronousCommit'
      FailoverMode               = 'Automatic'
      PsDscRunAsCredential       = (Get-AutomationPSCredential 'cred_sqladuser')
      DependsOn                  = '[SqlWaitForAG]SQLConfigureAG-WaitAG'
    }
  }
}