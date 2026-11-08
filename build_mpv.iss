[Setup]
; Unique identifier for the application in the Windows Registry
AppId=MPV_Player_Automated
AppName=MPV Player
; This version string will be dynamically replaced by GitHub Actions during the CI/CD pipeline
AppVersion={#MyAppVersion}
UninstallDisplayName=MPV Player
UninstallDisplayIcon={app}\mpv.exe
SetupIconFile={#SourceDir}\installer\mpv-icon.ico

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

; Notify Windows of environment changes (required for PATH modifications to take effect without reboot)
ChangesEnvironment=yes

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

; 4. Add {app} to system-wide PATH environment variable
; System-wide PATH (requires admin)
; Note: Removal is handled in CurUninstallStepChanged(usUninstall) to avoid deleting other paths
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: NeedsAddPath('{app}')

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

// Checks if the specified path is already in the system PATH environment variable
// Returns True if the path needs to be added (not already present)
function NeedsAddPath(Param: String): Boolean;
var
  OrigPath: String;
begin
  // Check system PATH (HKLM)
  // We only need to add if not present
  Result := False;
  
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
  begin
    if Pos(';' + Param + ';', ';' + OrigPath + ';') > 0 then
    begin
      Result := False;
      Exit;
    end;
  end;
  
  // Path not found, needs to be added
  Result := True;
end;

// Removes {app} from the system PATH environment variable during uninstall
procedure RemoveAppFromSystemPath();
var
  OrigPath, NewPath, AppPath: String;
begin
  AppPath := ExpandConstant('{app}');
  // Remove trailing backslash if present to normalize
  if (Length(AppPath) > 0) and (AppPath[Length(AppPath)] = '\') then
    SetLength(AppPath, Length(AppPath) - 1);
  
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
  begin
    NewPath := OrigPath;
    
    // 1. Replace middle: ;{app}; -> ;
    while Pos(';' + AppPath + ';', NewPath) > 0 do
      Delete(NewPath, Pos(';' + AppPath + ';', NewPath), Length(AppPath) + 1);
      
    // 2. Replace end: ;{app} -> ""
    if (Length(NewPath) >= Length(AppPath) + 1) and 
       (Copy(NewPath, Length(NewPath) - Length(AppPath), Length(AppPath) + 1) = ';' + AppPath) then
      Delete(NewPath, Length(NewPath) - Length(AppPath), Length(AppPath) + 1);
      
    // 3. Replace start: {app}; -> ""
    if (Length(NewPath) >= Length(AppPath) + 1) and 
       (Copy(NewPath, 1, Length(AppPath) + 1) = AppPath + ';') then
      Delete(NewPath, 1, Length(AppPath) + 1);
      
    // 4. Replace standalone: {app} -> ""
    if NewPath = AppPath then
      NewPath := '';
    
    // Clean up any double semicolons
    while Pos(';;', NewPath) > 0 do
      Delete(NewPath, Pos(';;', NewPath), 1);
    
    // Trim leading/trailing semicolons
    if (Length(NewPath) > 0) and (NewPath[1] = ';') then
      Delete(NewPath, 1, 1);
    if (Length(NewPath) > 0) and (NewPath[Length(NewPath)] = ';') then
      Delete(NewPath, Length(NewPath), 1);
    
    if NewPath <> OrigPath then
    begin
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath);
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

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Remove {app} from system PATH before uninstall begins
    RemoveAppFromSystemPath();
  end;
end;
