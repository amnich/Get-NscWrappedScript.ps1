# Get-NscWrappedScript
Get entries from NSClient++ nsc.ini file in Wrapped Scripts section.  

Returns command line, script path (if present in script's directory) and status.

    PS > Get-NscWrappedScript
    Command                                                    Script                                                           Enabled
    -------                                                    ------                                                           -------
    ;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs      False
    ;check_test_ps1=check_test.ps1 arg1 arg2                                                                                      False
    ;check_test_bat=check_test.bat arg1 arg2                                                                                      False
    ;check_battery=check_battery.vbs                                                                                              False
    ;check_printer=check_printer.vbs                                                                                              False
    ;check_updates=check_updates.vbs                           C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_updates.vbs   False

    PS > Get-NscWrappedScript -ScriptName .vbs
    Command                                                    Script                                                           Enabled
    -------                                                    ------                                                           -------
    ;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs      False
    ;check_updates=check_updates.vbs                           C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_updates.vbs   False

    PS > Get-NscWrappedScript -CommandLine check_test
    Command                                                    Script                                                        Enabled
    -------                                                    ------                                                        -------
    ;check_test_vbs=check_test.vbs /arg1:1 /arg2:1 /variable:1 C:\Program Files\NSClient++-0.3.9-x64-\scripts\check_test.vbs   False
    ;check_test_ps1=check_test.ps1 arg1 arg2                                                                                   False
    ;check_test_bat=check_test.bat arg1 arg2
