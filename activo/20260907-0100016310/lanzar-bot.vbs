Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "C:\\DevQuasar\\Qrystalos\\QrystalosBA"
sh.Run """C:\Users\JOSE MANUEL\AppData\Local\Programs\Python\Python312\pythonw.exe"" C:\DevQuasar\Qrystalos\QrystalosBA\scripts\cursor_bot.py --caso 20260907-0100016310 --motivo activar", 0, False
