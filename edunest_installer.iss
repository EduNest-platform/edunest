[Setup]
AppName=EduNest
AppVersion=1.0.0
DefaultDirName={pf}\EduNest
DefaultGroupName=EduNest
UninstallDisplayIcon={app}\EduNest.exe
OutputDir=.
OutputBaseFilename=EduNestInstaller
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\EduNest"; Filename: "{app}\\EduNest.exe"
Name: "{group}\\Uninstall EduNest"; Filename: "{uninstallexe}"
Name: "{userdesktop}\\EduNest"; Filename: "{app}\\EduNest.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Code]
function InitializeSetup(): Boolean;
begin
  if DirExists(ExpandConstant('{app}')) then
  begin
    MsgBox('An existing version of EduNest was found. The installer will upgrade your app and preserve your settings.', mbInformation, MB_OK);
  end;
  Result := True;
end;
