Configuration File_Source {
    Param (
        # Path of source folder
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SrcPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SqlVer
    )

    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration' -ModuleVersion 9.1.0

    # File CopySource {
    #     Ensure = 'Present'
    #     Type = 'Directory'
    #     Recurse = $true
    #     SourcePath = $SrcPath
    #     DestinationPath = 'C:\Packages'
    #     Credential = New-Object System.Management.Automation.PSCredential( $StrgAccUsr, (ConvertTo-SecureString $StrgAccPass -AsPlainText -Force))
    # }
    # Archive ExtractSource {
    #     Ensure = "Present"
    #     Path = "C:\Packages\$SqlVer.zip"
    #     Destination = "C:\"
    # }
    xArchive GetSource 
    {
      Ensure = "Present"
      Path = "$SrcPath\$SqlVer.zip"
      Destination = "C:\"
      Credential = (Get-AutomationPSCredential 'cred_store')
    }
}