@echo off

SET database.name="NHSBTDev"
SET sql.files.directory="Stralfors.NHSBT.Import.Database"
SET server.database="(local)\SQLEXPRESS"
SET repository.path="https://github.com/fhelje/FSWatcher"
SET version.file="Stralfors.NHSBT.Import.Database\_buildInfo.xml"
SET version.xpath="//buildInfo/version"
SET environment="FRANKWIN8"

rh.exe /d=%database.name% /f=%sql.files.directory% /s=%server.database% /vf=%version.file% /vx=%version.xpath% /r=%repository.path% /env=%environment% /simple --noninteractive

