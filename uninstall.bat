@echo off
cls
powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy','Bypass','-NoProfile','-File','%~dp0src\uninstall.ps1' -Verb runAs"
