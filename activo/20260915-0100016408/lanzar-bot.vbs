Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "C:\\DevQuasar\\Qrystalos\\QrystalosBA"
sh.Run """C:\Users\JOSE MANUEL\AppData\Local\Programs\Python\Python312\pythonw.exe"" C:\DevQuasar\Qrystalos\QrystalosBA\scripts\cursor_bot.py --caso 20260915-0100016408 --motivo activar", 0, False
