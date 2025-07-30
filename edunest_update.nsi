; NSIS Script for EduNest Updater - Final Simplified Version

!define APP_NAME "EduNest"
!define APP_VERSION "1.3.0"
!define APP_PUBLISHER "EduNest Team"
!define APP_EXE "EduNest.exe"
!define UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

;--------------------------------
; Installer Attributes
;--------------------------------

Name "${APP_NAME} Update ${APP_VERSION}"
OutFile "EduNestUpdate.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin
ManifestDPIAware true

;--------------------------------
; Modern UI Configuration
;--------------------------------

!include "MUI2.nsh"

!define MUI_FONT "Segoe UI"
!define MUI_ICON "assets\images\edunest-desktop.ico"
!define MUI_UNICON "assets\images\edunest-desktop.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\images\Wizard.bmp"

; --- Pages (Simplified for an Updater) ---
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!insertmacro MUI_PAGE_FINISH

; --- Uninstaller Pages ---
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Installer Section
;--------------------------------

Section "Update Files"
  SectionIn RO

  ; Read the install location from the registry
  ReadRegStr $INSTDIR HKLM "${UNINSTALL_KEY}" "InstallLocation"

  ; Set the output path to that directory
  SetOutPath $INSTDIR

  ; Install all application files, overwriting old ones
  File /r "build\windows\x64\runner\Release\*.*"

  ; Update the version number in the registry
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
SectionEnd

;--------------------------------
; Uninstaller Section (for reference)
;--------------------------------

Section "Uninstall"
  Delete "$INSTDIR\*.*"
  Delete "$SMPROGRAMS\${APP_NAME}\*.*"
  RmDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$STARTUP\${APP_NAME}.lnk"
  RmDir /r "$INSTDIR"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
SectionEnd