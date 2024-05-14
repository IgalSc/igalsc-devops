@ECHO OFF
SET OUTPUT="D:\Cleanup.log"
forfiles -p "D:\LogFiles\W3SVC2" -s -m *.* /D -3 /C "cmd /c del @path" >> %OUTPUT% 2>&1
forfiles -p "D:\LogFiles\W3SVC1" -s -m *.* /D -3 /C "cmd /c del @path" >> %OUTPUT% 2>&1
forfiles -p "D:\LogFiles\W3SVC3" -s -m *.* /D -3 /C "cmd /c del @path" >> %OUTPUT% 2>&1
forfiles -p "D:\LogFiles\W3SVC4" -s -m *.* /D -3 /C "cmd /c del @path" >> %OUTPUT% 2>&1
forfiles -p "D:\LogFiles\PerfMonitor" -s -m *.* /D -3 /C "cmd /c del @path" >> %OUTPUT% 2>&1
del /S /q c:\Windows\Temp\*.* >> %OUTPUT% 2>&1
for /d %%x in (%systemdrive%\$Recycle.bin\*) do @rd /s /q "%%x" >> %OUTPUT% 2>&1
del /q /s d:\$Recycle.bin\* >> %OUTPUT% 2>&1
exit 0