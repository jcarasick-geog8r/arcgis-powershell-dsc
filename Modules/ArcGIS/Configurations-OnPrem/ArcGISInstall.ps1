Configuration ArcGISInstall{
    param(
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        $ServiceCredential,

        [Parameter(Mandatory=$false)]
        [System.Boolean]
        $ServiceCredentialIsDomainAccount = $false,

        [Parameter(Mandatory=$false)]
        [System.Boolean]
        $ServiceCredentialIsMSA = $false
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName @{ModuleName="ArcGIS";ModuleVersion="3.0.1"}
    Import-DscResource -Name ArcGIS_Install
    Import-DscResource -Name ArcGIS_WebAdaptorInstall
    Import-DscResource -Name ArcGIS_InstallMsiPackage
    Import-DscResource -Name ArcGIS_InstallPatch

    Node $AllNodes.NodeName {

        if($Node.Thumbprint){
            LocalConfigurationManager
            {
                CertificateId = $Node.Thumbprint
            }
        }

        if($null -ne $ServiceCredential){
            if(-not($ServiceCredentialIsDomainAccount)){
                User ArcGIS_RunAsAccount
                {
                    UserName = $ServiceCredential.UserName
                    Password = $ServiceCredential
                    FullName = 'ArcGIS Run As Account'
                    Ensure = "Present"
                    PasswordChangeRequired = $false
                    PasswordNeverExpires = $true
                }
            }
        }

        $NodeRoleArray = @()
        if($Node.Role -icontains "Server")
        {
            $NodeRoleArray += "Server"
        }
        if($Node.Role -icontains "Portal")
        {
            $NodeRoleArray += "Portal"
        }
        if($Node.Role -icontains "DataStore")
        {
            $NodeRoleArray += "DataStore"
        }
        if($Node.Role -icontains "ServerWebAdaptor")
        {
            $NodeRoleArray += "ServerWebAdaptor"
        }
        if($Node.Role -icontains "PortalWebAdaptor")
        {
            $NodeRoleArray += "PortalWebAdaptor"
        }
        if($Node.Role -icontains "Desktop")
        {
            $NodeRoleArray += "Desktop"
        }
        if($Node.Role -icontains "Pro")
        {
            $NodeRoleArray += "Pro"
        }
        if($Node.Role -icontains "LicenseManager")
        {
            $NodeRoleArray += "LicenseManager"
        }
        if($Node.Role -icontains "SQLServer"){
            $NodeRoleArray += "SQLServer"
        }
        if($Node.Role -icontains "SQLServerClient"){
            $NodeRoleArray += "SQLServerClient"
        }

        for ( $i = 0; $i -lt $NodeRoleArray.Count; $i++ )
        {
            $NodeRole = $NodeRoleArray[$i]
            Switch($NodeRole)
            {
                'Server'
                {
                    $ServerTypeName = if($ConfigurationData.ConfigData.ServerRole -ieq "NotebookServer" -or $ConfigurationData.ConfigData.ServerRole -ieq "MissionServer" ){ $ConfigurationData.ConfigData.ServerRole }else{ "Server" }

                    ArcGIS_Install ServerInstall
                    {
                        Name = $ServerTypeName
                        Version = $ConfigurationData.ConfigData.Version
                        Path = $ConfigurationData.ConfigData.Server.Installer.Path
                        Arguments = if($ConfigurationData.ConfigData.ServerRole -ieq "NotebookServer" -or $ConfigurationData.ConfigData.ServerRole -ieq "MissionServer"){ "/qn InstallDir=`"$($ConfigurationData.ConfigData.Server.Installer.InstallDir)`"" }else{ "/qn InstallDir=`"$($ConfigurationData.ConfigData.Server.Installer.InstallDir)`" INSTALLDIR1=`"$($ConfigurationData.ConfigData.Server.Installer.InstallDirPython)`"" } 
                        Ensure = "Present"
                    }

                    if ($ConfigurationData.ConfigData.Server.Installer.PatchesDir) {
                        ArcGIS_InstallPatch ServerInstallPatch
                        {
                            Name = $ServerTypeName
                            Version = $ConfigurationData.ConfigData.Version
                            PatchesDir = $ConfigurationData.ConfigData.Server.Installer.PatchesDir
                            Ensure = "Present"
                        }
                    }
                    
                    if($ConfigurationData.ConfigData.GeoEventServer) 
                    { 
                        ArcGIS_Install GeoEventServerInstall
                        {
                            Name = "GeoEvent"
                            Version = $ConfigurationData.ConfigData.Version
                            Path = $ConfigurationData.ConfigData.GeoEventServer.Installer.Path
                            Arguments = if($ConfigurationData.ConfigData.GeoEventServer.EnableGeoeventSDK){ "/qn ADDLOCAL=GeoEvent,SDK"}else{ "/qn" };
                            Ensure = "Present"
                        }
                    }

                }
                'Portal'
                {                    
                    ArcGIS_Install "PortalInstall$($Node.NodeName)"
                    { 
                        Name = "Portal"
                        Version = $ConfigurationData.ConfigData.Version
                        Path = $ConfigurationData.ConfigData.Portal.Installer.Path
                        Arguments = "/qn INSTALLDIR=`"$($ConfigurationData.ConfigData.Portal.Installer.InstallDir)`" CONTENTDIR=`"$($ConfigurationData.ConfigData.Portal.Installer.ContentDir)`""
                        Ensure = "Present"
                    }

                    $VersionArray = $ConfigurationData.ConfigData.Version.Split(".")
                    $MajorVersion = $VersionArray[1]
                    $MinorVersion = if($VersionArray.Length -gt 2){ $VersionArray[2] }else{ 0 }
                    if((($MajorVersion -eq 7 -and $MinorVersion -eq 1) -or ($MajorVersion -ge 8)) -and $ConfigurationData.ConfigData.Portal.Installer.WebStylesPath){
                        ArcGIS_Install "WebStylesInstall$($Node.NodeName)"
                        { 
                            Name = "WebStyles"
                            Version = $ConfigurationData.ConfigData.Version
                            Path = $ConfigurationData.ConfigData.Portal.Installer.WebStylesPath
                            Arguments = "/qb"
                            Ensure = "Present"
                        }
                    }

                    if ($ConfigurationData.ConfigData.Portal.Installer.PatchesDir) {
                        ArcGIS_InstallPatch PortalInstallPatch
                        {
                            Name = "Portal"
                            Version = $ConfigurationData.ConfigData.Version
                            PatchesDir = $ConfigurationData.ConfigData.Portal.Installer.PatchesDir
                            Ensure = "Present"
                        }
                    } 
                }
                'DataStore'
                {
                    ArcGIS_Install DataStoreInstall
                    { 
                        Name = "DataStore"
                        Version = $ConfigurationData.ConfigData.Version
                        Path = $ConfigurationData.ConfigData.DataStore.Installer.Path
                        Arguments = "/qn InstallDir=`"$($ConfigurationData.ConfigData.DataStore.Installer.InstallDir)`""
                        Ensure = "Present"
                    }

                    if ($ConfigurationData.ConfigData.DataStore.Installer.PatchesDir) {
                        ArcGIS_InstallPatch DataStoreInstallPatch
                        {
                            Name = "DataStore"
                            Version = $ConfigurationData.ConfigData.Version
                            PatchesDir = $ConfigurationData.ConfigData.DataStore.Installer.PatchesDir
                            Ensure = "Present"
                        }
                    } 
                }
                {($_ -eq "ServerWebAdaptor") -or ($_ -eq "PortalWebAdaptor")}
                {
                    $PortalWebAdaptorSkip = $False
                    if(($Node.Role -icontains 'ServerWebAdaptor') -and ($Node.Role -icontains 'PortalWebAdaptor'))
                    {
                        if($NodeRole -ieq "PortalWebAdaptor")
                        {
                            $PortalWebAdaptorSkip = $True
                        }
                    }
                    
                    if(-not($PortalWebAdaptorSkip))
                    {
                        if(($Node.Role -icontains 'PortalWebAdaptor') -and $ConfigurationData.ConfigData.PortalContext)
                        {
                            ArcGIS_WebAdaptorInstall WebAdaptorInstallPortal
                            { 
                                Context = $ConfigurationData.ConfigData.PortalContext 
                                Path = $ConfigurationData.ConfigData.WebAdaptor.Installer.Path
                                Arguments = "/qn VDIRNAME=$($ConfigurationData.ConfigData.PortalContext) WEBSITE_ID=1";
                                Ensure = "Present"
                                Version = $ConfigurationData.ConfigData.Version
                            } 
                        }

                        if(($Node.Role -icontains 'ServerWebAdaptor') -and $Node.ServerContext)
                        {
                            ArcGIS_WebAdaptorInstall WebAdaptorInstallServer
                            { 
                                Context = $Node.ServerContext 
                                Path = $ConfigurationData.ConfigData.WebAdaptor.Installer.Path
                                Arguments = "/qn VDIRNAME=$($ConfigurationData.ConfigData.ServerContext) WEBSITE_ID=1";
                                Ensure = "Present"
                                Version = $ConfigurationData.ConfigData.Version
                            } 
                        }
                    }
                }
                'SQLServerClient'
                {
                    if($ConfigurationData.ConfigData.SQLServerClient){
                        $TempFolder = "$($env:SystemDrive)\Temp"
                        if(Test-Path $TempFolder){ Remove-Item -Path $TempFolder -Recurse }
                        if(-not(Test-Path $TempFolder)){ New-Item $TempFolder -ItemType directory }

                        foreach($Client in $ConfigurationData.ConfigData.SQLServerClient){
                            $ODBCDriverName = $Client.Name
                            $FileName = Split-Path $Client.InstallerPath -leaf

                            File "SetupCopy$($ODBCDriverName.Replace(' ', '_'))"
                            {
                                Ensure = "Present"
                                Type = "File"
                                SourcePath = $Client.InstallerPath
                                DestinationPath = "$TempFolder\$FileName"  
                            }
                        
                            ArcGIS_InstallMsiPackage "AIMP_$($ODBCDriverName.Replace(' ', '_'))"
                            {
                                Name = $ODBCDriverName
                                Path = $ExecutionContext.InvokeCommand.ExpandString("$TempFolder\$FileName")
                                Ensure = "Present"
                                ProductId = $Client.ProductId
                                Arguments = $Client.Arguments
                            } 
                        }

                        if(Test-Path $TempFolder){ Remove-Item -Path $TempFolder -Recurse }
                    }
                }
                'SQLServer'
                {
                    WindowsFeature "NET"
                    {
                        Ensure = "Present"
                        Name = "NET-Framework-Core"
                    }
                    
                    $InstallerPath = $Node.SQLServerInstallerPath

                    Script SQLServerInstall
                    {
                        GetScript = {
                            $null
                        }
                        SetScript = {
                            $ExtractPath = "$env:SystemDrive\temp\sql"
                            if(Test-Path $ExtractPath)
                            {
                                Remove-Item -Recurse -Force $ExtractPath
                            }
                            & cmd.exe /c "$using:InstallerPath /q /x:$ExtractPath"
                            Write-Verbose "Done Extracting SQL Server"
                            Start-Sleep -Seconds 60
                            if(Test-Path "$ExtractPath\SETUP.exe")
                            {
                                Write-Verbose "Starting SQL Server Install"
                                & "$ExtractPath\SETUP.exe" /q /IACCEPTSQLSERVERLICENSETERMS /ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /TCPENABLED=1 /SQLSVCACCOUNT='NT AUTHORITY\SYSTEM' /SQLSYSADMINACCOUNTS='NT AUTHORITY\SYSTEM' /AGTSVCACCOUNT="NT AUTHORITY\Network Service"
                                Write-Verbose "Server Install Completed"
                                Remove-Item -Recurse -Force $ExtractPath
                            }
                            else
                            {
                                Write-Verbose "Something Went Wrong"
                            }
                        }
                        TestScript = {
                            if (Test-Path "HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL")
                            {
                                $True
                            } 
                            else 
                            {
                                $False
                            }
                        }
                    }
                }
                'Desktop' {
                    $Argumments =""
                    if($ConfigurationData.ConfigData.Desktop.SeatPreference -ieq "Fixed"){
                        $Argumments = "/qb ADDLOCAL=`"$($ConfigurationData.ConfigData.Desktop.InstallFeatures)`" INSTALLDIR=`"$($ConfigurationData.ConfigData.Desktop.Installer.InstallDir)`" INSTALLDIR1=`"$($ConfigurationData.ConfigData.Desktop.Installer.InstallDirPython)`" DESKTOP_CONFIG=`"$($ConfigurationData.ConfigData.Desktop.DesktopConfig)`" MODIFYFLEXDACL=`"$($ConfigurationData.ConfigData.Desktop.ModifyFlexdAcl)`""
                    }else{
                        $Argumments = "/qb ADDLOCAL=`"$($ConfigurationData.ConfigData.Desktop.InstallFeatures)`" INSTALLDIR=`"$($ConfigurationData.ConfigData.Desktop.Installer.InstallDir)`" INSTALLDIR1=`"$($ConfigurationData.ConfigData.Desktop.Installer.InstallDirPython)`" ESRI_LICENSE_HOST=`"$($ConfigurationData.ConfigData.Desktop.EsriLicenseHost)`" SOFTWARE_CLASS=`"$($ConfigurationData.ConfigData.Desktop.SoftwareClass)`" SEAT_PREFERENCE=`"$($ConfigurationData.ConfigData.Desktop.SeatPreference)`" DESKTOP_CONFIG=`"$($ConfigurationData.ConfigData.Desktop.DesktopConfig)`"  MODIFYFLEXDACL=`"$($ConfigurationData.ConfigData.Desktop.ModifyFlexdAcl)`""
                    }
                    if($ConfigurationData.ConfigData.Desktop.EnableEUEI -and $ConfigurationData.ConfigData.Desktop.EnableEUEI -eq $False){
                        $Arguments += " ENABLEEUEI=0"
                    }  

                    ArcGIS_Install DesktopInstall
                    { 
                        Name = "Desktop"
                        Version = $ConfigurationData.ConfigData.DesktopVersion
                        Path = $ConfigurationData.ConfigData.Desktop.Installer.Path
                        Arguments =   $Argumments
                        Ensure = "Present"
                    }

                    if ($ConfigurationData.ConfigData.Desktop.Installer.PatchesDir) {
                        ArcGIS_InstallPatch DesktopInstallPatch
                        {
                            Name = "Desktop"
                            Version = $ConfigurationData.ConfigData.DesktopVersion
                            PatchesDir = $ConfigurationData.ConfigData.Desktop.Installer.PatchesDir
                            Ensure = "Present"
                        }
                    }
                }
                'Pro'
                {
                    $PortalList = if($ConfigurationData.ConfigData.Pro.PortalList){ $ConfigurationData.ConfigData.Pro.PortalList }else{ "https://arcgis.com" }
                    $Arguments = "/qb ALLUSERS=`"$($ConfigurationData.ConfigData.Pro.AllUsers)`" Portal_List=`"$PortalList`" AUTHORIZATION_TYPE=`"$($ConfigurationData.ConfigData.Pro.AuthorizationType)`" SOFTWARE_CLASS=`"$($ConfigurationData.ConfigData.Pro.SoftwareClass)`" BLOCKADDINS=`"$($ConfigurationData.ConfigData.Pro.BlockAddIns)`" INSTALLDIR=`"$($ConfigurationData.ConfigData.Pro.Installer.InstallDir)`""
                    if($ConfigurationData.ConfigData.Pro.AuthorizationType -ieq "CONCURRENT_USE"){
                        $Arguments += " ESRI_LICENSE_HOST=`"$($ConfigurationData.ConfigData.Pro.EsriLicenseHost)`"" 
                    }

                    if($ConfigurationData.ConfigData.Pro.LockAuthSettings -and $ConfigurationData.ConfigData.Pro.LockAuthSettings -eq $False){
                        $Arguments += " LOCK_AUTH_SETTINGS=False"
                    }   
                    if($ConfigurationData.ConfigData.Pro.EnableEUEI -and $ConfigurationData.ConfigData.Pro.EnableEUEI -eq $False){
                        $Arguments += " ENABLEEUEI=0"
                    } 
                    if($ConfigurationData.ConfigData.Pro.CheckForUpdatesAtStartup -and $ConfigurationData.ConfigData.Pro.CheckForUpdatesAtStartup -eq $False){
                        $Arguments += " CHECKFORUPDATESATSTARTUP=0"
                    }   

                    ArcGIS_Install ProInstall{
                        Name = "Pro"
                        Version = $ConfigurationData.ConfigData.ProVersion
                        Path = $ConfigurationData.ConfigData.Pro.Installer.Path
                        Arguments = $Arguments
                        Ensure = "Present"
                    }

                    if ($ConfigurationData.ConfigData.Pro.Installer.PatchesDir) {
                        ArcGIS_InstallPatch ProInstallPatch
                        {
                            Name = "Pro"
                            Version = $ConfigurationData.ConfigData.ProVersion
                            PatchesDir = $ConfigurationData.ConfigData.Pro.Installer.PatchesDir
                            Ensure = "Present"
                        }
                    }
                }
                'LicenseManager'
                {
                    ArcGIS_Install LicenseManagerInstall{
                        Name = "LicenseManager"
                        Version = $ConfigurationData.ConfigData.LicenseManagerVersion
                        Path = $ConfigurationData.ConfigData.LicenseManager.Installer.Path
                        Arguments = "/qb INSTALLDIR=`"$($ConfigurationData.ConfigData.LicenseManager.Installer.InstallDir)`""
                        Ensure = "Present"
                    }
                }
            }
        }
    }
}