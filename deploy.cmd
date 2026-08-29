@echo off
setlocal
rem Deploy shell for this repo: terraform + az + git in a container.
rem Requires Rancher Desktop (or Docker Desktop) to be running.
rem
rem   deploy              opens a shell in terraform/ with the tools ready
rem   deploy ^<command^>    runs one command, e.g.  deploy terraform plan

docker info >nul 2>&1 && goto :docker_ok
echo Docker engine is not reachable. Start Rancher Desktop, wait for it
echo to finish starting, then try again.
rem keep the window open when launched by double-click (not from a shell)
echo %cmdcmdline% | find /i "%~f0" >nul && pause
exit /b 1
:docker_ok

cd /d "%~dp0"
docker compose run --rm --build tools %*
