Set wshShell = CreateObject("WScript.shell")
wshShell.run "mfgtool2.exe -c ""linux"" -l ""SDCard"" -s ""board=sabresd"" -s ""mmc=1"" -s ""6uluboot=14x14evk"" -s ""6uldtb=14x14-evk"" -s ""6ulldtb=14x14-evk"""
Set wshShell = Nothing
