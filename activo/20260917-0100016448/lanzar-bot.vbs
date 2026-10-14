Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = "C:\\DevQuasar\\Qrystalos\\QrystalosBA"
sh.Run """C:\Users\JOSE MANUEL\AppData\Local\Programs\Python\Python312\pythonw.exe"" C:\DevQuasar\Qrystalos\QrystalosBA\scripts\cursor_bot.py --caso 20260917-0100016448 --motivo chat", 0, False
