[Setup]
AppName=EduNest
AppVersion=1.3.0
AppPublisher=EduNest Team
AppPublisherURL=https://github.com/Ranojitdas/EduNest-desktop
AppSupportURL=https://github.com/Ranojitdas/EduNest-desktop/issues
AppUpdatesURL=https://github.com/Ranojitdas/EduNest-desktop/releases
DefaultDirName={autopf}\EduNest
DefaultGroupName=EduNest
UninstallDisplayIcon={app}\edunest-desktop.ico
OutputDir=.
OutputBaseFilename=EduNestUpdate
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=no
DisableFinishedPage=no
AllowNoIcons=yes
ShowLanguageDialog=no
LanguageDetectionMethod=locale
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousSetupType=yes
UsePreviousTasks=yes
UsePreviousUserInfo=yes
AppId={{A1B2C3D4-E5F6-47A8-9B0C-1234567890AB}}
SetupIconFile=assets/images/edunest-desktop.ico
VersionInfoVersion=1.3.0.0
VersionInfoCompany=EduNest Team
VersionInfoDescription=EduNest Desktop Application Update
VersionInfoCopyright=Copyright (c) 2024 EduNest Team

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "assets/images/edunest-desktop.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\EduNest"; Filename: "{app}\EduNest.exe"; IconFilename: "{app}\edunest-desktop.ico"
Name: "{group}\{cm:UninstallProgram,EduNest}"; Filename: "{uninstallexe}"; IconFilename: "{app}\edunest-desktop.ico"

[Registry]
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: string; ValueName: "DisplayName"; ValueData: "EduNest"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#SetupSetting("AppVersion")}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: string; ValueName: "Publisher"; ValueData: "{#SetupSetting("AppPublisher")}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: string; ValueName: "InstallLocation"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: string; ValueName: "UninstallString"; ValueData: "{uninstallexe}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: dword; ValueName: "NoModify"; ValueData: 1; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1"; ValueType: dword; ValueName: "NoRepair"; ValueData: 1; Flags: uninsdeletekey

[Run]
Filename: "{app}\EduNest.exe"; Description: "{cm:LaunchProgram,EduNest}"; Flags: nowait postinstall skipifsilent; IconFilename: "{app}\edunest-desktop.ico"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('EduNest has been updated successfully!'+#13#10+#13#10+'Open the app to see what''s new.', mbInformation, MB_OK);
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  // Show update message on the ready page
  if CurPageID = wpReady then
  begin
    if FileExists(WizardDirValue + '\EduNest.exe') then
    begin
      MsgBox('A previous version of EduNest was detected.'+#13#10+#13#10+'The installer will now update your app to version {#SetupSetting("AppVersion")}.', mbInformation, MB_OK);
    end;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check if EduNest is already installed
  if not FileExists(ExpandConstant('{autopf}\EduNest\EduNest.exe')) and 
     not FileExists(ExpandConstant('{pf}\EduNest\EduNest.exe')) then
  begin
    MsgBox('EduNest is not currently installed on this computer.'+#13#10+#13#10+'Please use the full installer instead of the update.', mbError, MB_OK);
    Result := False;
  end;
end;

