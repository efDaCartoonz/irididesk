@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64_x86 -vcvars_ver=%IRIDI_VCVARS_VERSION% >nul
link.exe %*
