Configuration xSQLInstance # Based on function or env needed
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName SqlServerDsc

  Node localhost # VM or Computer name
  {
 
    WindowsFeature NetFramework # Resource in module
    {
      Name   = 'NET-Framework-45-Core'
      Ensure = 'Present'
    }

    xArchive GetSource 
    {
      Ensure = "Present"
      Path = "\\ntglabdevdata.file.core.windows.net\sqlsources\SQL2019.zip"
      Destination = "C:\"
      Credential = (Get-AutomationPSCredential 'cred_store')
    }

#------------------
# Setup SQL Server
#------------------
    SqlSetup DB 
    {
      DependsOn             = '[Archive]ExtractSource'
      InstanceName          = 'MSSQLSERVER'
      SourcePath            = 'C:\SQL2019'
      Features              = 'SQLENGINE'
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
      DependsOn              ='[SqlSetup]DB'
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
      SourcePath            = 'C:\SQL2019'
    }

    SqlDatabase 'CreateDbaDatabase'
    {
      DependsOn             = '[SqlSetup]DB'
      InstanceName          = 'MSSQLSERVER'
      Name                  = 'DBA'
    }
  }
}