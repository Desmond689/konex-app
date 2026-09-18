@echo off
REM Minimal gradlew batch file placeholder. Installs rely on a system gradle install if wrapper JAR is missing.nIF NOT DEFINED GRADLE_HOME (
  gradle %*
) ELSE (
  "%GRADLE_HOME%\bin\gradle" %*
)
