Function Get-NscWrappedScript {
<#
.SYNOPSIS
Get entries from NSClient++ nsc.ini file in Wrapped Scripts.
.DESCRIPTION
Get entries from NSClient++ nsc.ini or nsclient.ini file in Wrapped Scripts.
Return command line, script path if present in script's directory and status.
.PARAMETER ScriptName
Filter by script name (if command that uses this file is found in ini)
.PARAMETER CommandLine
Filter by command in ini
.PARAMETER ComputerName
Specifies the computers on which the command runs.
.PARAMETER NscFolder
Directory where NSClient++ is installed.
Default is path from running service or $env:ProgramFiles\NSClient*
.EXAMPLE
Get-NscWrappedScript
Command                                                    Script                                                           Enabled
-------                                                    ------                                                           -------
;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs      False
;check_test_ps1=check_test.ps1 arg1 arg2                                                                                      False
;check_test_bat=check_test.bat arg1 arg2                                                                                      False
;check_battery=check_battery.vbs                                                                                              False
;check_printer=check_printer.vbs                                                                                              False
;check_updates=check_updates.vbs                           C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_updates.vbs   False
.EXAMPLE
Get-NscWrappedScript -ScriptName .vbs
Command                                                    Script                                                           Enabled
-------                                                    ------                                                           -------
;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs      False
;check_updates=check_updates.vbs                           C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_updates.vbs   False
.EXAMPLE
Get-NscWrappedScript -CommandLine check_test
Command                                                    Script                                                        Enabled
-------                                                    ------                                                        -------
;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs   False
;check_test_ps1=check_test.ps1 arg1 arg2                                                                                   False
;check_test_bat=check_test.bat arg1 arg2
.LINK
https://github.com/amnich/Get-NscWrappedScript.ps1
.NOTES
    Author: Adam Mnich
                                                                                      
#>
    [CmdletBinding()]
	param(
		[parameter(ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [String[]]$ComputerName,
        $ScriptName,
        [parameter()]
        [ValidateNotNullorEmpty()]
        $CommandLine,        
        $NscFolder 
    )
    BEGIN {
        $patternFileName = "=(([^\\]*)\.(\w+))"
        $patternWS = "[\[|[\/settings\/external scripts\/][w|W]rapped [s|S]cripts\]"
        $NSCini = "nsc.ini", "nsclient.ini"
		$VerboseSwitch = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
        $ScriptBlock = {
            try {
                if ($using:ComputerName) {
				    if ($using:VerboseSwitch){
						$VerbosePreference = "continue"
					}
					Write-Verbose "Running remote on $env:computername"
                    $NscFolder = $using:NscFolder   
                    $NSCini = $using:NSCini                    
                    $patternWS = $using:patternWS
                    $CommandLine = $using:CommandLine
                    $patternFileName = $using:patternFileName
                }
            }
            catch {
                Write-Verbose "Running local"
            }
            #find NSC folder
			$NscFolder_regex = "[A-Z]:\\.*\\NSC.*\.exe"
			if ($NscFolder -eq $null){
				if ((Get-WmiObject win32_service | ?{$_.DisplayName -like 'NSClient*' -and $_.state -eq "Running"} | 
						select -ExpandProperty PathName) -match $NscFolder_regex) {
						$NscFolder = Split-Path $Matches[0]
					}
				else {
					$NscFolder = "$env:ProgramFiles\NSClient*"
				}
			}
            $Folders = Get-ChildItem "$NSCFolder*"
            Write-Verbose "Folders found $($folders.count)"
            Write-Debug "$($folders | out-string)"
            foreach ($folder in $Folders) {
                try {					
                    $NscIniPath = "$($folder.FullName)\$($NSCini[0])"
                    if (!(Test-Path $NscIniPath)) {
                        $NscIniPath = "$($folder.FullName)\$($NSCini[1])"
                        if (!(Test-Path $NscIniPath)) {
                            Write-Error "$NscIniPath missing"
                        }
                    }                    
                    $NscIniContent = Get-Content $NscIniPath
                    Write-Verbose "  NSC ini content: $($NscIniContent.count) lines"
                    #get only Wrapper Script entries from ini
                    $WrappedCommands = $NscIniContent | foreach-object {
                        if ($_ -match $patternWS) {
                            $display = $true
                        }
                        elseif ($_ -match "\[.*\]") {
                            $display = $false
                        }

                        if ($display -and $_ -notmatch "\[.*\]") {
                            $_
                        }   
                    }
                    Write-Verbose "    Wrapped Scripts: $($WrappedCommands.count) lines"
                    #filter results by command
                    if ($CommandLine) {
                        $wrappedCommands = $wrappedCommands | Where-Object {$_ -match [regex]::Escape($commandLine)}    
                    }
                    #get all scripts in folder
                    $scriptFiles = Get-ChildItem "$($folder.fullname)\scripts\*.*"
                    Write-Debug "$($scriptFiles | out-string)"
                    foreach ($wrappedCommand in ($wrappedCommands | Where-Object {$_.length -gt 0})) {
                        #create output object
                        $wrappedObject = New-Object pscustomobject -Property @{
                            Command = $WrappedCommand
                            Script  = $null
                            Enabled = $true
                            Ini = $NscIniPath
                        }
                        #find filename in command
                        if ($WrappedCommand -match $patternFileName) {
                            $commandFile = $Matches[1]
                            Write-Verbose "    $commandFile"
                            #check if command is disabled
                            if ($WrappedCommand -match "^;") {
                                $wrappedObject.enabled = $false
                            }
                            #find file in script folder
                            $commandScript = $scriptFiles | Where-Object {$_.Name -eq $commandFile}
                            if ($commandScript) {
                                #add path to script property
                                $wrappedObject.script = $commandScript
                                Write-Verbose "      Command script: $commandScript"
                            } 
                        }
                        #filter if $scriptName was provided
                        if ($ScriptName -and $wrappedObject.script -match [regex]::Escape($ScriptName)) {
                            $wrappedObject | Select-Object Command, Script, Enabled, Ini
                        }
                        #display if no $scriptName 
                        elseif (!($ScriptName)) {
                            $wrappedObject | Select-Object Command, Script, Enabled, Ini
                        }                     
                    }                    
                }
                catch {
                    $error[0]
                }
            }

        }
    }
    PROCESS {
        if ($ComputerName) {
            Invoke-Command -ScriptBlock $scriptblock -ComputerName $ComputerName
        }
        else {
            & $ScriptBlock
        }  
    }
}
