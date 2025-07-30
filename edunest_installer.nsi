; NSIS Script for EduNest
; Last Updated: July 28, 2025

;--------------------------------
; 1. Defines and General Info
;--------------------------------

!define APP_NAME "EduNest"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "EduNest Team"
!define APP_URL "https://github.com/Ranojitdas/EduNest-desktop"
!define APP_EXE "EduNest.exe"
!define UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

;--------------------------------
; 2. Installer Attributes
;--------------------------------

Name "${APP_NAME} ${APP_VERSION}"
OutFile "EduNestInstaller.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel admin
ManifestDPIAware true ; Ensures sharp text and UI on high-resolution screens

;--------------------------------
; 3. Modern UI Configuration
;--------------------------------

!include "MUI2.nsh"

; --- Set a modern, clear font ---
!define MUI_FONT "Segoe UI"

; --- Installer Icon ---
!define MUI_ICON "assets\images\edunest-desktop.ico"
!define MUI_UNICON "assets\images\edunest-desktop.ico"

; --- Wizard Image (Welcome and Finished pages) ---
; NOTE: The recommended size for this bitmap is 164x314 pixels.
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\images\edunest_anime.bmp"

; --- Pages ---
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!insertmacro MUI_PAGE_FINISH

; --- Uninstaller Pages ---
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; --- Language ---
!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; 4. Installer Sections
;--------------------------------

Section "EduNest (Required)" SectionApp
  SectionIn RO ; Read-only section, cannot be unchecked

  SetOutPath $INSTDIR

  ; Install all application files
  File /r "build\windows\x64\runner\Release\*.*"

  ; Store installation folder
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"

  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "URLInfoAbout" "${APP_URL}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Start Menu Shortcut" SectionStartMenu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall EduNest.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section "Desktop Shortcut" SectionDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Run at Startup" SectionStartup
  CreateShortCut "$STARTUP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd


;--------------------------------
; 5. Descriptions for Components Page
;--------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionApp} "Installs the main application files."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionStartMenu} "Adds shortcuts to the Start Menu."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionDesktop} "Adds a shortcut to the Desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SectionStartup} "Runs the application automatically when Windows starts."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
; 6. Uninstaller Section
;--------------------------------

Section "Uninstall"
  ; Remove files
  Delete "$INSTDIR\*.*"

  ; Remove Start Menu shortcuts
  Delete "$SMPROGRAMS\${APP_NAME}\*.*"
  RmDir "$SMPROGRAMS\${APP_NAME}"

  ; Remove Desktop shortcut
  Delete "$DESKTOP\${APP_NAME}.lnk"

  ; Remove Startup shortcut
  Delete "$STARTUP\${APP_NAME}.lnk"

  ; Remove installation directory
  RmDir /r "$INSTDIR"

  ; Remove registry keys
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
SectionEnd