[Setup]
; Unique identifier for the application in the Windows Registry
AppId=MPV_Player_Automated
AppName=MPV Player
; This version string will be dynamically replaced by GitHub Actions during the CI/CD pipeline
AppVersion={#MyAppVersion}
UninstallDisplayName=MPV Player
UninstallDisplayIcon={app}\mpv.exe
SetupIconFile=.\installer\mpv-icon.ico

; Modern Windows architecture support
ArchitecturesInstallIn64BitMode=x64compatible
DefaultDirName={autopf}\MPV Player
PrivilegesRequired=admin

; UI CONTROL (Silent/Hybrid Mode)
; Hides unnecessary wizard pages for a faster, zero-click approach when automated
DisableWelcomePage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes

; COMPRESSION OPTIMIZATION (Cloud-ready)
; Uses multi-threading to speed up the build process in GitHub Actions runners
OutputDir=.\Output
OutputBaseFilename=mpv_installer_x64
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

[Languages]
; Force the installer language strictly to Universal English
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startmenuicon"; Description: "Create a Start Menu shortcut"; GroupDescription: "Additional icons:"
; Desktop shortcut is unchecked by default to respect modern UI standards
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MPV Player"; Filename: "{app}\mpv.exe"; Tasks: startmenuicon
Name: "{autodesktop}\MPV Player"; Filename: "{app}\mpv.exe"; Tasks: desktopicon

[Registry]
; 1. Base File Identity (ProgID)
Root: HKLM; Subkey: "SOFTWARE\Classes\mpv.file"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Classes\mpv.file"; ValueType: string; ValueName: ""; ValueData: "MPV Media File"
Root: HKLM; Subkey: "SOFTWARE\Classes\mpv.file\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\mpv.exe,0"
Root: HKLM; Subkey: "SOFTWARE\Classes\mpv.file\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\mpv.exe"" ""%1"""

; 2. Friendly App Name (Forces Windows to display "MPV Player" in 'Open With...' menus)
Root: HKLM; Subkey: "SOFTWARE\Classes\Applications\mpv.exe"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Classes\Applications\mpv.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "MPV Player"
Root: HKLM; Subkey: "SOFTWARE\Classes\Applications\mpv.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\mpv.exe"" ""%1"""

; 3. Native Windows Settings Integration (RegisteredApplications)
Root: HKLM; Subkey: "SOFTWARE\Clients\Media\MPV Player"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Clients\Media\MPV Player\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "MPV Player"
Root: HKLM; Subkey: "SOFTWARE\Clients\Media\MPV Player\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "MPV Player"
Root: HKLM; Subkey: "SOFTWARE\RegisteredApplications"; ValueType: string; ValueName: "MPV Player"; ValueData: "SOFTWARE\Clients\Media\MPV Player\Capabilities"; Flags: uninsdeletevalue

[Code]
// Dynamic PerceivedType Scanner Engine
procedure RegisterPerceivedTypes();
var
  Names: TArrayOfString;
  I: Integer;
  ExtName, PType: String;
begin
  // Query HKEY_CLASSES_ROOT for all registered file extensions
  if RegGetSubkeyNames(HKEY_CLASSES_ROOT, '', Names) then
  begin
    for I := 0 to GetArrayLength(Names) - 1 do
    begin
      ExtName := Names[I];
      
      // Fast filtering: Process only keys that start with a dot (extensions)
      if (Length(ExtName) > 1) and (Copy(ExtName, 1, 1) = '.') then
      begin
        // Check if the extension is classified as video or audio by the OS
        if RegQueryStringValue(HKEY_CLASSES_ROOT, ExtName, 'PerceivedType', PType) then
        begin
          PType := Lowercase(PType);
          if (PType = 'video') or (PType = 'audio') then
          begin
            // A. Declare official capability for Windows 11 Default Apps menu
            RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Clients\Media\MPV Player\Capabilities\FileAssociations', ExtName, 'mpv.file');
            
            // B. Inject into OpenWithProgids for deep system integration priority
            RegWriteStringValue(HKEY_CLASSES_ROOT, ExtName + '\OpenWithProgids', 'mpv.file', '');
          end;
        end;
      end;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  UninstallKey: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Execute the scanner immediately after files are copied
    RegisterPerceivedTypes();
    
    // Dynamic removal of the estimated size record to maintain a clean UI in Windows Settings
    UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\MPV_Player_Automated_is1';
    RegDeleteValue(HKEY_LOCAL_MACHINE, UninstallKey, 'EstimatedSize');
  end;
end;