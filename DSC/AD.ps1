Configuration ADServer
{
#---------------
# Import Module 
#---------------  
  Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
  Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 6.0.1
  Import-DscResource -Module ComputerManagementDsc -ModuleVersion 8.4.0
  Import-DscResource -ModuleName DnsServerDsc -ModuleVersion 3.0.0
  Import-DscResource -Module NetworkingDsc -ModuleVersion 8.2.0

  $cred_adadmin = Get-AutomationPSCredential 'cred_adadmin'
  $cred_svcsql01 = Get-AutomationPSCredential 'cred_svcsql01'
  $cred_svcsql02 = Get-AutomationPSCredential 'cred_svcsql02'
  $cred_admin = Get-AutomationPSCredential 'cred_admin'

  Node DC1
  {    
    xWindowsFeature 'ADDS'
    {
        Name   = 'AD-Domain-Services'
        Ensure = 'Present'
    }

    xWindowsFeature 'ADDSTools'
    {
        Name = "RSAT-ADDS"
        Ensure = "Present"
    }

    xWindowsFeature 'RSAT'
    {
        Name   = 'RSAT-AD-PowerShell'
        Ensure = 'Present'
    }          

    # Create the ADDS DC
    ADDomain 'DC' {
        DomainName                      = 'ntglab.com'
        Credential                      = $cred_admin
        SafemodeAdministratorPassword   = $cred_admin
        ForestMode                      = 'WinThreshold'
        DependsOn                       = '[xWindowsFeature]ADDS'
    }   
    
    WaitForADDomain 'DscForestWait'
    {
        DomainName      = 'ntglab.com'
        WaitTimeout     = 600
        RestartCount    = 2
        Credential      = $cred_admin
        DependsOn       = '[ADDomain]DC'
    }

    ADDomainController 'DomainControllerAllProperties'
    {
        DomainName                    = 'ntglab.com'
        Credential                    = $cred_admin
        SafeModeAdministratorPassword = $cred_admin
        DatabasePath                  = 'C:\Windows\NTDS'
        LogPath                       = 'C:\Windows\Logs'
        SysvolPath                    = 'C:\Windows\SYSVOL'
        IsGlobalCatalog               = $true
        DependsOn                     = '[WaitForADDomain]DscForestWait'
    }

    DnsServerPrimaryZone 'AddPrimaryZone'
    {
        Ensure        = 'Present'                
        Name          = '1.0.10.in-addr.arpa'
    }

    ADUser 'AdAdmin'
    {
        DomainName          = 'ntglab.com'
        UserName            = $cred_adadmin.UserName
        Password            = $cred_adadmin
        PasswordNeverResets = $true
        Ensure              = 'Present'
        DependsOn           = '[ADDomain]DC'
    }
    
    ADGroup 'AddAdAdminToDomainAdmins'
    {
        GroupName           = 'Domain Admins'
        MembersToInclude    = $cred_adadmin.UserName
        Ensure              = 'Present'
        DependsOn           = '[ADUser]AdAdmin'
    }

    # ADUser 'SvcSql01'
    # {
    #     DomainName          = 'ntglab.com'
    #     UserName            = $cred_svcsql01.UserName
    #     Password            = $cred_svcsql01
    #     PasswordNeverResets = $true
    #     Ensure              = 'Present'
    #     Path                = 'CN=Users,DC=ntglab,DC=com'
    #     DependsOn           = '[ADDomain]DC'
    # }
    
    # ADGroup 'AddSvcSql01ToDomainAdmins'
    # {
    #     GroupName           = 'Domain Admins'
    #     MembersToInclude    = $cred_svcsql01.UserName
    #     Ensure              = 'Present'
    #     DependsOn           = '[ADUser]SvcSql01'
    # }

    # ADUser 'SvcSql02'
    # {
    #     DomainName          = 'ntglab.com'
    #     UserName            = $cred_svcsql02.UserName
    #     Password            = $cred_svcsql02
    #     PasswordNeverResets = $true
    #     Ensure              = 'Present'
    #     Path                = 'CN=Users,DC=ntglab,DC=com'
    #     DependsOn           = '[ADDomain]DC'
    # }
    
    # ADGroup 'AddUserToDomainAdmins'
    # {
    #     GroupName           = 'Domain Admins'
    #     MembersToInclude    = ($cred_adadmin.UserName, $cred_svcsql01.UserName, $cred_svcsql02.UserName)
    #     Ensure              = 'Present'
    #     DependsOn           = '[ADUser]SvcSql02'
    # }

    DnsServerAddress 'DnsServerAddress'
    {
        Address        = '127.0.0.1'
        InterfaceAlias = 'Ethernet 2'
        AddressFamily  = 'IPv4'
        Validate       = $true
    }

    Firewall 'AllowFirewallTCP'
    {
        Name                  = 'AllowTCP'
        DisplayName           = 'Allow (TCP-in)'
        Ensure                = 'Present'
        Enabled               = 'True'
        Direction             = 'Inbound'
        LocalPort             = ('135', '389', '3268', '53', '88', '445')
        Protocol              = 'TCP'
        Profile               = ('Domain', 'Private')
    }

    Firewall 'AllowFirewallUDP'
    {
        Name                  = 'AllowUDP'
        DisplayName           = 'Allow (UDP-in)'
        Ensure                = 'Present'
        Enabled               = 'True'
        Direction             = 'Inbound'
        LocalPort             = ('389', '53', '88')
        Protocol              = 'UDP'
        Profile               = ('Domain', 'Private')
    }
  }
}