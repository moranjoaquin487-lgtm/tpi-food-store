@echo off
rem U6 - Lo ejecuta la tarea programada "FoodStore\Respaldo" (ver programar_respaldo.cmd).
rem Corre backup_foodstore.sh con Git Bash y deja toda la salida en logs\tarea_programada.log,
rem asi un fallo a las 02:00 queda registrado aunque no haya nadie mirando.
cd /d "%~dp0"
if not exist logs mkdir logs
echo ==== %date% %time% >> logs\tarea_programada.log
rem La ruta va entre comillas simples para bash: si tiene espacios, cd no falla (code review U4-U7, #11).
"C:\Program Files\Git\bin\bash.exe" -l -c "cd '%CD:\=/%' && ./backup_foodstore.sh" >> logs\tarea_programada.log 2>&1
echo codigo de salida: %errorlevel% >> logs\tarea_programada.log
