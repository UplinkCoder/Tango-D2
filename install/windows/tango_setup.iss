; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "Tango"
#define MyAppVerName "Tango"
#define MyAppPublisher "The Tango Group"
#define MyAppURL "http://www.dsource.org/projects/tango"


[Setup]
AppName={#MyAppName}
AppVerName={#MyAppVerName}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
CreateAppDir=no
AllowNoIcons=yes
LicenseFile=C:\projects\tango_install\licenses.txt
InfoBeforeFile=C:\projects\tango_install\pre_installation.rtf
InfoAfterFile=C:\projects\tango_install\post_installation.rtf
OutputBaseFilename=setup
Compression=lzma
SolidCompression=yes
DisableDirPage=yes
DefaultGroupName=Tango



[Icons]
;Name: "{group}\My Program"; Filename: "{app}\MYPROG.EXE"; WorkingDir: "{app}"
Name: {group}\Uninstall Tango; Filename: {uninstallexe}
Name: {group}\Switch To Phobos; Filename: {code:DMDRootLocation}\bin\switch.exe; Parameters: phobos {code:DMDRootLocation}; Flags: runminimized; IconFilename: {code:DMDRootLocation}\bin\switch_dmd.ico
Name: {group}\Switch To Tango; Filename: {code:DMDRootLocation}\bin\switch.exe; Parameters: tango {code:DMDRootLocation}; Flags: runminimized; IconFilename: {code:DMDRootLocation}\bin\switch_tango.ico

[Files]
Source: C:\projects\tango_install\unzip.exe; DestDir: {tmp}; Flags: ignoreversion
Source: C:\projects\tango_install\switch.exe; DestDir: {code:DMDRootLocation}\bin; Flags: ignoreversion
Source: C:\projects\tango_install\switch_dmd.ico; DestDir: {code:DMDRootLocation}\bin; Flags: ignoreversion
Source: C:\projects\tango_install\switch_tango.ico; DestDir: {code:DMDRootLocation}\bin; Flags: ignoreversion

[Languages]
Name: english; MessagesFile: compiler:Default.isl

[_ISToolDownload]
;Source: http://svn.dsource.org/projects/tango/downloads/tango-0.95-beta1-installer.zip; DestDir: {tmp}; DestName: tango.zip
Source: http://63.99.9.206/tango/downloads/tango-0.95-beta1-installer.zip; DestDir: {tmp}; DestName: tango.zip
;Source: http://www.rentbayarea.com/build.zip; DestDir: {tmp}; DestName: build.zip; Check: ShouldInstallBuild

[Run]
Filename: {tmp}\unzip.exe; Parameters: -o tango.zip -d {code:DMDRootLocation}; WorkingDir: {tmp}; Flags: runminimized; Check: ShouldInstallBuild
Filename: {tmp}\unzip.exe; Parameters: "-o tango.zip -d {code:DMDRootLocation} -x ""bin/build.exe"""; WorkingDir: {tmp}; Flags: runminimized; Check: ShouldNotInstallBuild
Filename: {tmp}\unzip.exe; Parameters: -q; WorkingDir: {tmp}; Check: ShouldOverwritePhobos; Flags: runminimized



[CustomMessages]
TangoOptions_Caption=Tango Install Options
TangoOptions_Description=Here you can choose what options you want for your tango installation.
TangoOptions_Label1_Caption0=Install Directory ( DMD Root Directory )
TangoOptions_Label1_Hint0=This is the root location of your DMD installation, such as C:\dmd
TangoOptions_Label1_ShowHint0=True
TangoOptions_Label2_Caption0=Error: DMD Was not found in your PATH - please manually enter it's location
TangoOptions_Label3_Caption0=Tango Mirror
TangoOptions_DMDRootEdit_Hint0=This is the root location of your DMD installation, such as C:\dmd
TangoOptions_DMDRootEdit_ShowHint0=True
TangoOptions_DMDRootEdit_Text0=DMDRootEdit
TangoOptions_BrowseButton_Caption0=Browse
TangoOptions_OverwritePhobosCheck_Caption0=Overwrite phobos.lib , with the option to revert
TangoOptions_OverwritePhobosCheck_Hint0=This will replace your existing phobos.lib with tangos so you ca'n start using it immediately.
TangoOptions_OverwritePhobosCheck_ShowHint0=True
TangoOptions_TangoDocCheck_Caption0=Install Tango documentation ( full local documentation )
TangoOptions_TangoDocCheck_Hint0=Install Local Documentation
TangoOptions_TangoDocCheck_ShowHint0=True

TangoOptions_OverwriteBuildCfg_Caption0=Replace build.cfg with tango freindly version
TangoOptions_OverwriteBuildCfg_Hint0=Updates your build.cfg to -I/path/to/tango

TangoOptions_OverwriteScIni_Caption0=Replace sc.ini with tango freindly sc.ini
TangoOptions_OverwriteScIni_Hint0=Updates your sc.ini to -I/path/to/tango
TangoOptions_OverwriteScIni_ShowHint0=True
TangoOptions_TangoMirrorCombo_Hint0=The Mirror you wish to download tango from
TangoOptions_TangoMirrorCombo_ShowHint0=True
TangoOptions_TangoMirrorCombo_Line0=dsource.org
TangoOptions_InstallBuildCheck_Caption0=Install Bu[il]d v3.04
TangoOptions_InstallBuildCheck_Hint0=Bu[il]d is a compilation tool that greatly reduces build complex'ity, see http://www.dsource.org/projects/build for more details.
TangoOptions_InstallBuildCheck_ShowHint0=True

[Code]
// Function generated by ISTool.
function NextButtonClick(CurPage: Integer): Boolean;
begin
	Result := istool_download(CurPage);
end;


var
  Label1: TLabel;
  Label2: TLabel;
  Label3: TLabel;
  DMDRootEdit: TEdit;
  DMDRootDir: String;
  BrowseButton: TButton;
  OverwritePhobosCheck: TCheckBox;
  TangoDocCheck: TCheckBox;
  OverwriteScIni: TCheckBox;
  OverwriteBuildCfg: TCheckBox;
  TangoMirrorCombo: TComboBox;
  InstallBuildCheck: TCheckBox;
  PATHDirs : array [1 .. 100] of String;


{ Functions for getting Code }

function DMDRootLocation(Param : String ) :  String;
begin
	Result := DMDRootEdit.Text;
end;

{ Checks for downloading and installing }

function ShouldOverwritePhobos : Boolean;
begin

  if FileExists(DMDRootLocation('') + 'bin\build.cfg') = True
  then begin
    if MsgBox('You have a build configuration file at ' + DMDRootLocation('') + 'bin\build.cfg' + '.  Should I append an -I/path/to/tango to it ?'   , mbConfirmation ,   MB_YESNO ) = IDYES
    then begin
		FileCopy(DMDRootLocation('') + 'bin\build.cfg',DMDRootLocation('') + 'bin\build.cfg.phobos',True );
      if SaveStringToFile(DMDRootLocation('') + 'bin\build.cfg',#13#10 + 'CMDLINE= -I"' + DMDRootLocation('') + 'tango\"' + #13#10 , True ) = False
      then begin
        MsgBox('Error writing file: ' + DMDRootLocation('') + 'bin\build.cfg.  Ignoring.' ,  mbConfirmation, MB_OK);
      end
    end
  end else begin
		if  SaveStringToFile(DMDRootLocation('') + 'bin\build.cfg',#13#10 + 'CMDLINE= -I"' + DMDRootLocation('') + 'tango\"' + #13#10 , False ) = False
		then begin
		        MsgBox('Error writing file: ' + DMDRootLocation('') + 'bin\build.cfg.  Ignoring.' ,  mbConfirmation, MB_OK);
		end
	end;





	if FileCopy(DMDRootLocation('') + 'lib\phobos.lib',DMDRootLocation('') + 'lib\dmd_phobos.lib',True) = False
	then begin
		if ( FileExists(DMDRootLocation('') + 'lib\dmd_phobos.lib') ) = False
		then begin
			MsgBox('Could not locate phobos.lib , reverting will be unavailable.', mbConfirmation, MB_OK);
		end
	end;

	//if OverwritePhobosCheck.Checked = True
	if True
	then begin

		if FileCopy(DMDRootLocation('') + 'lib\tango_phobos.lib',DMDRootLocation('') + 'lib\phobos.lib',False) = False
		then begin
			MsgBox('Could not locate phobos.lib with Tango''s phobos.lib, please do so manually.', mbConfirmation, MB_OK);
		end;
		Result := True;
	end else begin
		Result := False;
	end;
end;


function ShouldInstallDoc() : Boolean;
begin
	if TangoDocCheck.Checked = True
	then begin
		Result := True;
	end else begin
		Result := False;
	end;
end;


function ShouldInstallBuild() : Boolean;
begin
	if InstallBuildCheck.Checked = True
	then begin
		Result := True;
	end else begin
		Result := False;
	end;
end;

function ShouldNotInstallBuild() : Boolean;
begin
	if ShouldInstallBuild() = True
	then begin
		Result := False;
	end else begin
		Result := True;
	end;
end;

function ShouldReplaceScIni() : Boolean;
begin
	if OverwriteScIni.Checked = True
	then begin
		Result := True;
	end else begin
		Result := False;
	end;


end;

function ShouldNotReplaceScIni() : Boolean;
begin
	if ShouldReplaceScIni() = True
	then begin
		Result := True;
	end else begin
		Result := False;
	end;

end;

function ShouldReplaceBuildCfg() : Boolean;
begin
	if OverwriteBuildCfg.Checked = True
	then begin
		Result := True;
	end else begin
		Result := False;
	end;


	if InstallBuildCheck.Checked <> True
	then begin
		Result := False;
	end;

end;

function ShouldNotReplaceBuildCfg() : Boolean;
begin
	if ShouldReplaceBuildCfg() = True
	then begin
		Result := False;
	end else begin
		Result := True;
	end;


end;

{ File System functions }


function Split(txt: String; separateur: String): Array of String;
var
  pl: Integer;
  I: Integer;
begin
  pl := 0
SetArrayLength(result, 1)
  for I := 1 to length(txt) do
  begin
    if txt[I] = separateur then begin
      pl := pl + 1;
      SetArrayLength(result, pl +1);
    end else begin
      result[pl] := result[pl] + txt[I];
  end;
  end;
end;

function GetDMDInstallLocation() : String;
var
	PATHStr : String;
	DMDPos : Integer;
	SlashPos : Integer;
	Strings : Array of String;
	I : Integer;
begin
  PATHStr := GetEnv('PATH');
	Strings := Split(PATHStr,';');
	I := 0;
	while  I < GetArrayLength(Strings) do
	begin
		//MsgBox(Strings[I], mbConfirmation, MB_YESNO) ;
		DMDPos := Pos('dmd\bin',Strings[I])

		if  DMDPos <> 0 then begin
			DMDRootDir := Strings[I];

			break;
		end;

		I := I + 1;
	end;

	// Strip off the end, need to test for trailing slash
	SlashPos := Pos('\bin',DMDRootDir);
	//MsgBox(DMDRootDir, mbConfirmation, MB_YESNO) ;
	//MsgBox(IntToStr(SlashPos), mbConfirmation, MB_YESNO) ;
	DMDRootDir := Copy(DMDRootDir,0, SlashPos );

	//MsgBox(DMDRootDir, mbConfirmation, MB_YESNO) ;
	Result := DMDRootDir;


end;


{ TangoOptions_Activate }

procedure TangoOptions_Activate(Page: TWizardPage);
begin
  // enter code here...
end;

{ TangoOptions_ShouldSkipPage }

function TangoOptions_ShouldSkipPage(Page: TWizardPage): Boolean;
begin
  Result := False;
end;

{ TangoOptions_BackButtonClick }

function TangoOptions_BackButtonClick(Page: TWizardPage): Boolean;
begin


  Result := True;
end;

{ TangoOptions_NextkButtonClick }

function TangoOptions_NextButtonClick(Page: TWizardPage): Boolean;
begin

	DMDRootEdit.Text := AddBackslash(DMDRootEdit.Text);
	if Not FileExists(DMDRootEdit.Text + 'bin\dmd.exe' )
	then begin
		if MsgBox('Your DMD Root location appears incorrect ( could not locate [ ' + DMDRootEdit.Text + 'bin\dmd.exe' +' ] , should we continue anyway ?', mbConfirmation, MB_YESNO) = IDYES
			then begin
				Result := True;
			end else begin
				Result := False;
			end;
	end else begin
		Result := True;
	end;


end;

{ TangoOptions_CancelButtonClick }

procedure TangoOptions_CancelButtonClick(Page: TWizardPage; var Cancel, Confirm: Boolean);
begin
  // enter code here...
end;

{ TangoOptions_CreatePage }

function TangoOptions_CreatePage(PreviousPageId: Integer): Integer;
var
  Page: TWizardPage;
begin
  Page := CreateCustomPage(
    PreviousPageId,
    ExpandConstant('{cm:TangoOptions_Caption}'),
    ExpandConstant('{cm:TangoOptions_Description}')
  );

{ Label1 }
  Label1 := TLabel.Create(Page);
  with Label1 do
  begin
    Parent := Page.Surface;
    Caption := ExpandConstant('{cm:TangoOptions_Label1_Caption0}');
    Left := ScaleX(8);
    Top := ScaleY(21);
    Width := ScaleX(200);
    Height := ScaleY(13);
    Hint := ExpandConstant('{cm:TangoOptions_Label1_Hint0}');
    ShowHint := True; //ExpandConstant('{cm:TangoOptions_Label1_ShowHint0}');
  end;

  { Label2 }
  Label2 := TLabel.Create(Page);
  with Label2 do
  begin
    Parent := Page.Surface;
    if GetDMDInstallLocation() = '' then begin
		Caption := ExpandConstant('{cm:TangoOptions_Label2_Caption0}');
		Color := 16777215;
		Font.Color := -16777208;
    end else begin
		Caption := '';
    end;

    Left := ScaleX(32);
    Top := ScaleY(0);
    Width := ScaleX(361);
    Height := ScaleY(13);
    Font.Height := ScaleY(-11);
    Font.Name := 'Tahoma';
    Font.Style := [fsUnderline];
  end;

  { Label3 }
  Label3 := TLabel.Create(Page);
  with Label3 do
  begin
    Parent := Page.Surface;
    Caption := ExpandConstant('{cm:TangoOptions_Label3_Caption0}');
    Left := ScaleX(8);
    Top := ScaleY(72);
    Width := ScaleX(61);
    Height := ScaleY(13);
  end;

  { DMDRootEdit }
  DMDRootEdit := TEdit.Create(Page);
  with DMDRootEdit do
  begin
    Parent := Page.Surface;
    Left := ScaleX(8);
    Top := ScaleY(41);
    Width := ScaleX(301);
    Height := ScaleY(21);
    Hint := ExpandConstant('{cm:TangoOptions_DMDRootEdit_Hint0}');
    ShowHint := True; //ExpandConstant('{cm:TangoOptions_DMDRootEdit_ShowHint0}');
    TabOrder := 0;
    Text := GetDMDInstallLocation();
  end;

  { BrowseButton }
//  BrowseButton := TButton.Create(Page);
//  with BrowseButton do
//  begin
//    Parent := Page.Surface;
//    Caption := ExpandConstant('{cm:TangoOptions_BrowseButton_Caption0}');
//    Left := ScaleX(328);
//    Top := ScaleY(40);
//    Width := ScaleX(75);
//    Height := ScaleY(23);
//    TabOrder := 1;
//  end;

  { OverwritePhobosCheck }
//  OverwritePhobosCheck := TCheckBox.Create(Page);
//  with OverwritePhobosCheck do
//  begin
//    Parent := Page.Surface;
//    Caption := ExpandConstant('{cm:TangoOptions_OverwritePhobosCheck_Caption0}');
//    Left := ScaleX(8);
//    Top := ScaleY(128);
//    Width := ScaleX(377);
//    Height := ScaleY(17);
//    Hint := ExpandConstant('{cm:TangoOptions_OverwritePhobosCheck_Hint0}');
//    Checked := True;
//    ShowHint := True; //ExpandConstant('{cm:TangoOptions_OverwritePhobosCheck_ShowHint0}');
//    State := cbChecked;
//    TabOrder := 3;
//  end;

  { TangoDocCheck }
//  TangoDocCheck := TCheckBox.Create(Page);
//  with TangoDocCheck do
//  begin
//    Parent := Page.Surface;
//    Caption := ExpandConstant('{cm:TangoOptions_TangoDocCheck_Caption0}');
//    Left := ScaleX(8);
//    Top := ScaleY(200);
//    Width := ScaleX(369);
//    Height := ScaleY(17);
//
//    Hint := ExpandConstant('{cm:TangoOptions_TangoDocCheck_Hint0}');
//    Checked := True;
//    ShowHint := True; //ExpandConstant('{cm:TangoOptions_TangoDocCheck_ShowHint0}');
//    State := cbChecked;
//    TabOrder := 5;
//  end;

//  { OverwriteScIni }
//  OverwriteScIni := TCheckBox.Create(Page);
//  with OverwriteScIni do
//  begin
//    Parent := Page.Surface;
//    Caption := ExpandConstant('{cm:TangoOptions_OverwriteScIni_Caption0}');
//    Left := ScaleX(8);
//    Top := ScaleY(152);
//    Width := ScaleX(361);
//    Height := ScaleY(17);
//    Hint := ExpandConstant('{cm:TangoOptions_OverwriteScIni_Hint0}');
//    Checked := True;
//    ShowHint := True; //ExpandConstant('{cm:TangoOptions_OverwriteScIni_ShowHint0}');
//    State := cbChecked;
//    TabOrder := 4;
//  end;


  { OverwriteBuildCfg }
//  OverwriteBuildCfg := TCheckBox.Create(Page);
//  with OverwriteBuildCfg do
//  begin
//    Parent := Page.Surface;
//    Caption := ExpandConstant('{cm:TangoOptions_OverwriteBuildCfg_Caption0}');
//    Left := ScaleX(8);
//    Top := ScaleY(152);
//    Width := ScaleX(361);
//    Height := ScaleY(17);
//    Hint := ExpandConstant('{cm:TangoOptions_OverwriteBuildCfg_Hint0}');
//    Checked := True;
//    ShowHint := True; //ExpandConstant('{cm:TangoOptions_OverwriteBuildCfg_ShowHint0}');
//    State := cbChecked;
//    TabOrder := 4;
//  end;

  { TangoMirrorCombo }
  TangoMirrorCombo := TComboBox.Create(Page);
  with TangoMirrorCombo do
  begin
    Parent := Page.Surface;
    Left := ScaleX(8);
    Top := ScaleY(88);
    Width := ScaleX(305);
    Height := ScaleY(21);
    Hint := ExpandConstant('{cm:TangoOptions_TangoMirrorCombo_Hint0}');
    Style := csDropDownList;
    ShowHint := True; //ExpandConstant('{cm:TangoOptions_TangoMirrorCombo_ShowHint0}');
    TabOrder := 2;
    Items.Add(ExpandConstant('{cm:TangoOptions_TangoMirrorCombo_Line0}'));

    ItemIndex := 0;
  end;

  { InstallBuildCheck }
  InstallBuildCheck := TCheckBox.Create(Page);
  with InstallBuildCheck do
  begin
    Parent := Page.Surface;
    Caption := ExpandConstant('{cm:TangoOptions_InstallBuildCheck_Caption0}');

    Left := ScaleX(8);
    Top := ScaleY(128);
    Width := ScaleX(361);
    Height := ScaleY(17);

    Hint := ExpandConstant('{cm:TangoOptions_InstallBuildCheck_Hint0}');
    Checked := True;
    ShowHint := True; //ExpandConstant('{cm:TangoOptions_InstallBuildCheck_ShowHint0}');
    State := cbChecked;
    TabOrder := 6;
  end;

  with Page do
  begin
    OnActivate := @TangoOptions_Activate;
    OnShouldSkipPage := @TangoOptions_ShouldSkipPage;
    OnBackButtonClick := @TangoOptions_BackButtonClick;
    OnNextButtonClick := @TangoOptions_NextButtonClick;
    OnCancelButtonClick := @TangoOptions_CancelButtonClick;
  end;

  Result := Page.ID;
end;

{ TangoOptions_InitializeWizard }

procedure InitializeWizard();
begin
  TangoOptions_CreatePage(wpWelcome);
end;
