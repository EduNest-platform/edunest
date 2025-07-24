[Setup]
AppName=EduNest
AppVersion=1.1.0
DefaultDirName={pf}\EduNest
DefaultGroupName=EduNest
UninstallDisplayIcon={app}\EduNest.exe
OutputDir=.
OutputBaseFilename=EduNestUpdate
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\EduNest"; Filename: "{app}\EduNest.exe"
Name: "{group}\Uninstall EduNest"; Filename: "{uninstallexe}"
Name: "{userdesktop}\EduNest"; Filename: "{app}\EduNest.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\EduNest.exe"; Description: "Launch EduNest"; Flags: nowait postinstall skipifsilent

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
  // Show update message after directory is selected, before install
  if CurPageID = wpReady then
  begin
    if FileExists(WizardDirValue + '\EduNest.exe') then
    begin
      MsgBox('A previous version of EduNest was detected.'+#13#10+#13#10+'The installer will now update your app to the latest version.', mbInformation, MB_OK);
    end;
  end;
end;

