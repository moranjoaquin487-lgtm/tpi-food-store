@echo off
rem U6 - Programa el respaldo diario de las 02:00 (tarea "FoodStore\Respaldo") y lo prueba una vez.
rem Se ejecuta una sola vez, en cmd. La tarea llama a respaldo_tarea.cmd, de esta misma carpeta.
schtasks /Create /F /SC DAILY /ST 02:00 /TN "FoodStore\Respaldo" /TR "\"%~dp0respaldo_tarea.cmd\""
if errorlevel 1 exit /b 1
rem Por defecto, Windows no inicia una tarea programada si la notebook esta a bateria.
rem El respaldo tiene que correr igual: se cambia esa condicion.
powershell -NoProfile -Command "Set-ScheduledTask -TaskPath \FoodStore\ -TaskName Respaldo -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable) | Out-Null"
if errorlevel 1 exit /b 1
schtasks /Run /TN "FoodStore\Respaldo"
