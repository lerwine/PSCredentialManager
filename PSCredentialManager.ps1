$Script:AddCommandArg = "Add";
$Script:ExitCommandArg = "Exit";
$Script:EditCommandArg = "Edit";
$Script:DeleteCommandArg = "Delete";
$Script:DbFolderName = "PSCredentials";
$Script:DbFolder = [Environment]::GetFolderPath([Environment.SpecialFolders]::MyDocuments) | Join-Path -ChildPath:$Script:DbFolderName;
$Script:DbFileName = "Logins.xml";
$Script:DbLocation = $Script:DbFolder | Join-Path -ChildPath:$Script:DbFileName;
$Script:RootClrNamespace = "Erwine.Leonard.T.PSCredentialManager";

Function Is-PSCredentialObject {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[AllowNull()]
		[object]$InputObject
	)

	Begin {
		$clrNamespace = '{0}.PSCredentialObject' -f $Script:RootClrNamespace;
	}

	Process {
		if ($InputObject -ne $null -and $InputObject -is [PSCustomObject] -and $clrNamespace -iin $InputObject.TypeNames) {
			$true | Write-Output;
		} else {
			$false | Write-Output
		}
	}
}

Function Load-PSCredentials {
	[CmdletBinding()]
	Param()

	if (-not ($Script:DbFolder | Test-Path)) {
		$parentFolder = $Script:DbFolder | Split-Path -Parent;
		if (-not ($parentFolder Test-Path)) { throw "Cannot create database file" }
		New-Item -Path:$parentFolder -Name:$Script:DbFolderName -ItemType:Directory | Out-Null;
	} else {
		if ($Script:DbFolder | Test-Path -Leaf) {
			throw "Cannot create database file because there is a file with the same name as the expected folder";
		}
	}

	if ($Script:DbLocation | Test-Path -Container) { throw "Cannot create database file because there is a folder with the same name as the expected file"; }

	if ($Script:DbLocation | Test-Path -Leaf) {
		$xmlDocument = New-Object Xml.XmlDocument;
		$xmlDocument.Load($Script:DbLocation);
			$sourceObjects = $xmlDocument.SelectNodes("/PSCredentialData/PSCredential") | Foreach-Object {
			$psCredentialElement = $_;
		};
	}
}

Function Save-PSCredentials {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[PSCustomObject]$PSCredentialObject
	)

	Begin {
		if (-not ($Script:DbFolder | Test-Path)) {
			$parentFolder = $Script:DbFolder | Split-Path -Parent;
			if (-not ($parentFolder Test-Path)) { throw "Cannot create database file" }
			New-Item -Path:$parentFolder -Name:$Script:DbFolderName -ItemType:Directory | Out-Null;
		} else {
			if ($Script:DbFolder | Test-Path -Leaf) {
				throw "Cannot create database file because there is a file with the same name as the expected folder";
			}
		}

		if ($Script:DbLocation | Test-Path -Container) { throw "Cannot create database file because there is a folder with the same name as the expected file"; }

		$xmlDocument = New-Object Xml.XmlDocument;
		$rootNode = $xmlDocument.CreateElement("PSCredentialData");
		$xmlDocument.AppendChild($rootNode);
	}

	Process {
		if ($PSCredentialObject -ne $null -and ($PSCredentialObject | Is-PSCredentialObject)) {
			$element = $xmlDocument.CreateElement("PSCredential");
			$rootNode.AppendChild($element);
			$attr = $xmlDocument.CreateAttribute("Id");
			$attr.Value = $PSCredentialObject.Id.ToString("D");
			$element.Attributes.Append($attr);
			$attr = $xmlDocument.CreateAttribute("Title");
			$attr.Value = $PSCredentialObject.Title;
			$element.Attributes.Append($attr);
			if ($PSCredentialObject.Login.Length -gt 0) {
				$attr = $xmlDocument.CreateAttribute("Login");
				$attr.Value = $PSCredentialObject.Login;
				$element.Attributes.Append($attr);
			}
			if ($PSCredentialObject.Url.Length -gt 0) {
				$attr = $xmlDocument.CreateAttribute("Url");
				$attr.Value = $PSCredentialObject.Url;
				$element.Attributes.Append($attr);
			}
			if ($PSCredentialObject.Password -ne $null) {
				$attr = $xmlDocument.CreateAttribute("Password");
				$attr.Value = $PSCredentialObject.Password | ConvertFrom-SecureString;
				$element.Attributes.Append($attr);
			}
			if ($PSCredentialObject.Pin -ne $null) {
				$attr = $xmlDocument.CreateAttribute("Pin");
				$attr.Value = $PSCredentialObject.Pin | ConvertFrom-SecureString;
				$element.Attributes.Append($attr);
			}
			if ($PSCredentialObject.Notes.Length -gt 0) {
				$el = $xmlDocument.CreateElement("Nodes");
				$el.AppendChild($xmlDocument.CreateCDataSection($PSCredentialObject.Notes));
				$element.AppendChild($el);
			}
		}
	}

	End {
		$settings = New-Object Xml.XmlTextWriterSettings;
		$settings.Indent = $true;
		$settings.Encoding = [Encoding]::UTF8;
		$writer = [Xml.XmlWriter]::Create($Script:DbLocation);
		$xmlDocument.WriteTo($writer);
		$writer.Flush();
		$writer.Close();
		$writer = $null;
	}
}

Function Get-PSCredentialObject {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Guid]$Id,

		[Parameter(Mandatory = $false)]
		[PSCustomObject[]]$PSCredentialObjects
	)

	Begin {
		$testedIds = @();
		$sourceObjects = &{ if ($PSBoundParameters.ContainsKey("")) { $PSCredentialObjects } else { Load-PSCredentials } };
	}

	Process {
		$sourceObjects | Where-Object { $_ -ne $null -and ($_ | Is-PSCredentialObject) -and $_.Id.Equals($Id) }
	}
}

Function New-PSCredentialObject {
	[CmdletBinding(DefaultParameterSetName = "ExplicitValues")]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "FromElement")]
		[Xml.XmlElement]$XmlElement,

		[Parameter(Mandatory = $true, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[string]$Title,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[AllowEmptyString()]
		[string]$Login,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[AllowEmptyString()]
		[string]$Url,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[AllowNull()]
		[SecureString]$Password,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[AllowNull()]
		[SecureString]$Pin,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[AllowEmptyString()]
		[string]$Notes,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true, ParameterSetName = "ExplicitValues")]
		[Guid]$Id
	)

	Process {
		$PSCredentialObject = New-Object PSCustomObject;
		$PSCredentialObject.PSTypeNames.Insert(0, ('{0}.PSCredentialObject' -f $Script:RootClrNamespace));

		$PSCredentialObject | Add-Member -Name:"_id" -MemberType:NoteProperty -Value:([Guid]::Empty);
		$PSCredentialObject | Add-Member -Name:"Id" -MemberType:ScriptProperty -PropertyType:[Guid] -Value:{
			if ($this._id -eq $null) {
				$this._id = [Guid]::NewGuid();
				return $this._id;
			}

			if ($this._id -is [Guid]) { return $this._id; }

			if ($this._id -is [byte[]]) {
				try {
					$this._id = New-Object Guid($this._id);
				} catch {
					$this._id = [Guid]::NewGuid();
				}
				return $this._id;
			}

			if ($this._id -isnot [string]) { $this._id = $this._id.ToString() }
			try {
				$this._id = New-Object Guid($this._id);
			} catch {
				$this._id = [Guid]::NewGuid();
			}
			return $this._id;
		};

		$PSCredentialObject | Add-Member -Name:"_title" -MemberType:NoteProperty -Value:"";
		$PSCredentialObject | Add-Member -Name:"Title" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._title -eq $null) {
				$this._title = "";
			} else if ($this._title -isnot [string]) {
				$this._title = $this._title.ToString();
			}

			return $this._title;
		} -SecondValue:{
			if ($_ -eq $null) {
				$this._title = "";
			} else if ($_ -isnot [string]) {
				$this._title = $_.ToString();
			} else {
				$this._title = $_;
			}
		};

		$PSCredentialObject | Add-Member -Name:"_login" -MemberType:NoteProperty -Value:"";
		$PSCredentialObject | Add-Member -Name:"Login" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._login -eq $null) {
				$this._login = "";
			} else if ($this._login -isnot [string]) {
				$this._login = $this._login.ToString();
			}

			return $this._login;
		} -SecondValue:{
			if ($_ -eq $null) {
				$this._login = "";
			} else if ($_ -isnot [string]) {
				$this._login = $_.ToString();
			} else {
				$this._login = $_;
			}
		};

		$PSCredentialObject | Add-Member -Name:"_url" -MemberType:NoteProperty -Value:"";
		$PSCredentialObject | Add-Member -Name:"Url" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._url -eq $null) {
				$this._url = "";
			} else if ($this._url -isnot [string]) {
				$this._url = $this._url.ToString();
			}

			return $this._url;
		} -SecondValue:{
			if ($_ -eq $null) {
				$this._url = "";
			} else if ($_ -isnot [string]) {
				$this._url = $_.ToString();
			} else {
				$this._url = $_;
			}
		};

		$PSCredentialObject | Add-Member -Name:"_password" -MemberType:NoteProperty -Value:$null;
		$PSCredentialObject | Add-Member -Name:"Password" -MemberType:ScriptProperty -PropertyType:[Security.SecureString] -Value:{
			if ($this._password -eq $null -or $this._password -is [Security.SecureString]) { return $this._password }

			$encPass = &{ if ($this._password -is [string]) { $this._password } else { $this._password.ToString() } };

			try {
				$this._password = ConvertTo-SecureString -String:$encPass;
			} catch {
				$this._password = ConvertTo-SecureString -String:$encPass -AsPlainText -Force;
			}
			return $this._password;
		} -SecondValue:{
			if ($_ -eq $null -or $_ -is [Security.SecureString]) {
				$this._password = $_;
				return;
			}

			$encPass = &{ if ($_ -is [string]) { $_ } else { $_.ToString() } };

			try {
				$this._password = ConvertTo-SecureString -String:$_;
			} catch {
				$this._password = ConvertTo-SecureString -String:$_ -AsPlainText -Force;
			}
		};

		$PSCredentialObject | Add-Member -Name:"_pin" -MemberType:NoteProperty -Value:$null;
		$PSCredentialObject | Add-Member -Name:"Pin" -MemberType:ScriptProperty -PropertyType:[Security.SecureString] -Value:{
			if ($this._pin -eq $null -or $this._pin -is [Security.SecureString]) { return $this._pin }

			$encPass = &{ if ($this._pin -is [string]) { $this._pin } else { $this._pin.ToString() } };

			try {
				$this._pin = ConvertTo-SecureString -String:$encPass;
			} catch {
				$this._pin = ConvertTo-SecureString -String:$encPass -AsPlainText -Force;
			}
			return $this._pin;
		} -SecondValue:{
			if ($_ -eq $null -or $_ -is [Security.SecureString]) {
				$this._pin = $_;
				return;
			}

			$encPass = &{ if ($_ -is [string]) { $_ } else { $_.ToString() } };

			try {
				$this._pin = ConvertTo-SecureString -String:$_;
			} catch {
				$this._pin = ConvertTo-SecureString -String:$_ -AsPlainText -Force;
			}
		};

		$PSCredentialObject | Add-Member -Name:"_notes" -MemberType:NoteProperty -Value:"";
		$PSCredentialObject | Add-Member -Name:"Notes" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._notes -eq $null) {
				$this._notes = "";
			} else if ($this._notes -isnot [string]) {
				$this._notes = $this._notes.ToString();
			}

			return $this._notes;
		} -SecondValue:{
			if ($_ -eq $null) {
				$this._notes = "";
			} else if ($_ -isnot [string]) {
				$this._notes = $_.ToString();
			} else {
				$this._notes = $_;
			}
		};

		if ($PSCmdlet.ParameterSetName -eq "FromElement") {
			$attr = $XmlElement.SelectSingleNode("@Id");
			if ($attr -eq $null -or $attr.Value.Trim().Length -eq 0) {
				$PSCredentialObject.Id = [Guid]::NewGuid();
			} else {
				try {
					$PSCredentialObject.Id = New-Object Guid($attr.Value.Trim());
				} catch {
					$PSCredentialObject.Id = [Guid]::NewGuid();
				{
			}

			$attr = $XmlElement.SelectSingleNode("@Title");
			if ($attr -ne $null) { $PSCredentialObject.Title = $attr.value }
			$attr = $XmlElement.SelectSingleNode("@Login");
			if ($attr -ne $null) { $PSCredentialObject.Login = $attr.value }
			$attr = $XmlElement.SelectSingleNode("@Url");
			if ($attr -ne $null) { $PSCredentialObject.Url = $attr.value }
			$attr = $XmlElement.SelectSingleNode("@Password");
			if ($attr -ne $null) {
				try {
					$PSCredentialObject.Password = $attr.value | ConvertTo-SecureString;
				} catch { }
			}
			$attr = $XmlElement.SelectSingleNode("@Pin");
			if ($attr -ne $null) {
				try {
					$PSCredentialObject.Pin = $attr.value | ConvertTo-SecureString;
				} catch { }
			}
			$el = $XmlElement.SelectSingleNode("Notes");
			if ($el -ne $null -and (-not ($el.IsEmpty))) { $PSCredentialObject.Notes = $el.InnerText }
		} else {
			$PSCredentialObject.Id = &{ if ($PSBoundParameters.ContainsKey("Id")) { $Id } else { [Guid]::NewGuid() } };
			$PSCredentialObject.Title = $Title;
			$PSCredentialObject.Login = $Login;
			$PSCredentialObject.Url = $Url;
			$PSCredentialObject.Password = $Password;
			$PSCredentialObject.Pin = $Pin;
			$PSCredentialObject.Notes = $Notes;
		}

		$PSCredentialObject | Write-Output;
	}
}

Function Decrypt-SecureString {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[Security.SecureString]$SecureString
	)

	Process {
		$bStr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);
		$result = $null;
		try {
			$result = [Runtime.InteropServices.marshal]::PtrToStringBSTR($bStr);
		} catch {
			throw 'Error decrypting secure string';
		} finally {
			[Runtime.InteropServices.Marshal]::FreeBSTR($bStr);
		}

		if ($result -ne $null) { $result | Write-Output }
	}
}

Function New-Padding {
	[CmdletBinding(DefaultParameterSetName = "NonUniform")]
	Param(
		[Parameter(Mandatory = $false, Position = 0, ParameterSetName = "NonUniform")]
		[int]$Left = 0,

		[Parameter(Mandatory = $false, Position = 1, ParameterSetName = "NonUniform")]
		[int]$Top = 0,

		[Parameter(Mandatory = $false, Position = 2, ParameterSetName = "NonUniform")]
		[int]$Right = 0,

		[Parameter(Mandatory = $false, Position = 3, ParameterSetName = "NonUniform")]
		[int]$Bottom = 0,

		[Parameter(Mandatory = $true, ParameterSetName = "Uniform")]
		[int]$Uniform = 0
	)

	if ($PSCmdlet.ParameterSetName -eq "Uniform") {
		(New-Object Windows.Forms.Padding($Uniform)) | Write-Output;
	} else {
		(New-Object Windows.Forms.Padding($Left, $Top, $Right, $Bottom)) | Write-Output;
	}
}

Function New-DataGridViewTextBoxColumn {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[ValidatePattern('^[a-zA-Z][\w_]*$')]
		[string]$Name,

		[Parameter(Mandatory = $false)]
		[AllowEmptyString()]
		[string]$HeaderText,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.DataGridViewAutoSizeColumnMode]$AutoSizeMode,

		[Parameter(Mandatory = $false)]
		[string]$DataPropertyName,

		[Parameter(Mandatory = $false)]
		[float]$FillWeight,

		[Parameter(Mandatory = $false)]
		[string]$ToolTipText,

		[Parameter(Mandatory = $false)]
		[Type]$ValueType,

		[Parameter(Mandatory = $false)]
		[int]$Width,

		[Parameter(Mandatory = $false)]
		[switch]$ReadOnly,

		[Parameter(Mandatory = $false)]
		[switch]$NotResizable,

		[Parameter(Mandatory = $false)]
		[switch]$Hidden
	)

	$DataGridViewTextBoxColumn = New-Object Windows.Forms.DataGridViewTextBoxColumn;
	$DataGridViewTextBoxColumn.Name = $Name;
	if ($PSBoundParameters.ContainsKey("HeaderText")) { $DataGridViewTextBoxColumn.HeaderText = $HeaderText }
	if ($PSBoundParameters.ContainsKey("AutoSizeMode")) { $DataGridViewTextBoxColumn.AutoSizeMode = $AutoSizeMode }
	if ($PSBoundParameters.ContainsKey("DataPropertyName")) { $DataGridViewTextBoxColumn.DataPropertyName = $DataPropertyName }
	if ($PSBoundParameters.ContainsKey("FillWeight")) { $DataGridViewTextBoxColumn.FillWeight = $FillWeight }
	if ($PSBoundParameters.ContainsKey("ToolTipText")) { $DataGridViewTextBoxColumn.ToolTipText = $ToolTipText }
	if ($PSBoundParameters.ContainsKey("ValueType")) { $DataGridViewTextBoxColumn.FillWeight = $ValueType }
	if ($PSBoundParameters.ContainsKey("Width")) { $DataGridViewTextBoxColumn.Width = $Width }
	$DataGridViewTextBoxColumn.ReadOnly = $ReadOnly;
	$DataGridViewTextBoxColumn.Resizable = (-not $NotResizable);
	$DataGridViewTextBoxColumn.Visible = (-not $Hidden);

	$DataGridViewTextBoxColumn | Write-Output;
}

Function New-DataGridViewButtonColumn {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[ValidatePattern('^[a-zA-Z][\w_]*$')]
		[string]$Name,

		[Parameter(Mandatory = $false)]
		[string]$CommandArg,

		[Parameter(Mandatory = $false)]
		[string]$Text,

		[Parameter(Mandatory = $false)]
		[AllowEmptyString()]
		[string]$HeaderText,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.DataGridViewAutoSizeColumnMode]$AutoSizeMode,

		[Parameter(Mandatory = $false)]
		[string]$DataPropertyName,

		[Parameter(Mandatory = $false)]
		[float]$FillWeight,

		[Parameter(Mandatory = $false)]
		[string]$ToolTipText,

		[Parameter(Mandatory = $false)]
		[Type]$ValueType,

		[Parameter(Mandatory = $false)]
		[int]$Width,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.FlatStyle]$FlatStyle,

		[Parameter(Mandatory = $false)]
		[switch]$UseColumnTextForButtonValue,

		[Parameter(Mandatory = $false)]
		[switch]$ReadOnly,

		[Parameter(Mandatory = $false)]
		[switch]$NotResizable,

		[Parameter(Mandatory = $false)]
		[switch]$Hidden
	)

	$DataGridViewButtonColumn = New-Object Windows.Forms.DataGridViewTextBoxColumn;
	$DataGridViewButtonColumn.Name = $Name;
	if ($PSBoundParameters.ContainsKey("HeaderText")) { $DataGridViewButtonColumn.HeaderText = $HeaderText }
	if ($PSBoundParameters.ContainsKey("Text")) { $DataGridViewButtonColumn.Text = $Text }
	if ($PSBoundParameters.ContainsKey("AutoSizeMode")) { $DataGridViewButtonColumn.AutoSizeMode = $AutoSizeMode }
	if ($PSBoundParameters.ContainsKey("DataPropertyName")) { $DataGridViewButtonColumn.DataPropertyName = $DataPropertyName }
	if ($PSBoundParameters.ContainsKey("FillWeight")) { $DataGridViewButtonColumn.FillWeight = $FillWeight }
	if ($PSBoundParameters.ContainsKey("ToolTipText")) { $DataGridViewButtonColumn.ToolTipText = $ToolTipText }
	if ($PSBoundParameters.ContainsKey("ValueType")) { $DataGridViewButtonColumn.FillWeight = $ValueType }
	if ($PSBoundParameters.ContainsKey("Width")) { $DataGridViewButtonColumn.Width = $Width }
	if ($PSBoundParameters.ContainsKey("FlatStyle")) { $DataGridViewButtonColumn.FlatStyle = $FlatStyle }
	$DataGridViewButtonColumn.UseColumnTextForButtonValue = $UseColumnTextForButtonValue;
	$DataGridViewButtonColumn.ReadOnly = $ReadOnly;
	$DataGridViewButtonColumn.Resizable = (-not $NotResizable);
	$DataGridViewButtonColumn.Visible = (-not $Hidden);

	if ($PSBoundParameters.ContainsKey("CommandArg")) {
		$DataGridViewButtonColumn | Add-Member -Name:"_commandArg" -MemberType:NoteProperty -Value:$CommandArg;
		$DataGridViewButtonColumn | Add-Member -Name:"CommandArg" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._commandArg -eq $null) {
				$this._commandArg = $this.Name;
			} else {
				if ($this._commandArg -isnot [string]) {
					$this._commandArg = $this._commandArg.ToString();
				}
				if ($this._commandArg.Length -eq 0) { $this._commandArg = $this.Name }
			}

			return $this._commandArg;
		}
	}

	$DataGridViewTextBoxColumn | Write-Output;
}

Function New-PasswordListingDataGridView {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
		[PSCustomObject]$PSCredentialObject,

		[Parameter(Mandatory = $false)]
		[ValidatePattern('^[a-zA-Z][\w_]*$')]
		[string]$Name = "PasswordListingDataGridView",

		[Parameter(Mandatory = $false)]
		[bool]$AutoSize = $true,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.Dock]$Dock = [Windows.Forms.Dock]::Fill,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.AnchorStyles]$Anchor = [Windows.Forms.AnchorStyles]::None,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.Padding]$Margin = New-Object Windows.Forms.Padding(0)
	)

	Begin {
		$dataSource = @();
		$credentialObjects = @();
	}

	Process {
		if ($PSCredentialObject -ne $null -and ($PSCredentialObject | Is-PSCredentialObject)) {
			$credentialObjects = $credentialObjects + @($PSCredentialObject);
			$dataSource = $dataSource + @({
				Id = $PSCredentialObject.Id;
				Title = $PSCredentialObject.Title;
				Login = $PSCredentialObject.Login;
				Url = $PSCredentialObject.Url;
			});
		}
	}

	End {
		$PasswordListingDataGridView  = New-Object Windows.Forms.DataGridView;
		$PasswordListingDataGridView.Name = $Name;
		$PasswordListingDataGridView.AutoSize = $AutoSize;
		$PasswordListingDataGridView.Dock = $Dock;
		$PasswordListingDataGridView.Anchor = $Anchor;
		$PasswordListingDataGridView.AutoGenerateColumns = $false;
		$PasswordListingDataGridView.ColumnHeadersVisible = true;

		$PasswordListingDataGridView.Columns.Add((New-DataGridViewTextBoxColumn -Name:"idTextBoxColumn" -DataPropertyName:"Id" -Hidden -ValueType:([Guid]))) | Out-Null;
		$PasswordListingDataGridView.Columns.Add((New-DataGridViewTextBoxColumn -Name:"loginTextBoxColumn" -DataPropertyName:"Login" -HeaderText:"Login"
			-AutoSizeMode:[Windows.Forms.DataGridViewAutoSizeColumnMode]::DisplayedCells -ValueType:([string]) -ReadOnly)) | Out-Null;
		$PasswordListingDataGridView.Columns.Add((New-DataGridViewTextBoxColumn -Name:"urlTextBoxColumn" -DataPropertyName:"Url" -HeaderText:"Url"
			-AutoSizeMode:[Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill -ValueType:([string]) -ReadOnly)) | Out-Null;
		$PasswordListingDataGridView.Columns.Add((New-DataGridViewButtonColumn -Name:"openButtonColumn" -Text:"Open" -HeaderText:"" -CommandArg:$Script:EditCommandArg
			-AutoSizeMode:[Windows.Forms.DataGridViewAutoSizeColumnMode]::DisplayedCells -NotResizable)) | Out-Null;
		$PasswordListingDataGridView.Columns.Add((New-DataGridViewButtonColumn -Name:"deleteButtonColumn" -Text:"Delete" -HeaderText:"" -CommandArg:$Script:DeleteCommandArg
			-AutoSizeMode:[Windows.Forms.DataGridViewAutoSizeColumnMode]::DisplayedCells -NotResizable)) | Out-Null;

		$PasswordListingDataGridView.Add_MouseDown({
			if ($sourceEventArgs.Button -ne [Windows.Forms.MouseButtons]::Left) { return }

			$hit = $sender.HitTest($sourceEventArgs.X, $sourceEventArgs.Y);
			if ($hit.Type -ne [Windows.Forms.DataGridViewHitTestType]::Cell) { return }
			$clickedRow = $sender.Rows[$hit.RowIndex];
			if ($clickedRow.DataBoundItem -eq $null -or $clickedRow.DataBoundItem.Id -eq $null) { return }
			$clickedCell = $clickedRow.Cells[$hit.ColumnIndex];
			if ($clickedCell -isnot [Windows.Forms.DataGridViewButtonCell] -or $clickedCell.CommandArg -eq $null) { return }
			for ($p = $sender.Parent; $p != null; $p = $p.Parent) {
				if ($p -is [Windows.Forms.Form]) {
					$p.PSUserAction = $sender.CommandArg;
					$p.PSActionItem = $sender.PSCredentialObjects | Where-Object { $_.Id.Equals($clickedRow.DataBoundItem.Id) };
					$p.Close();
					break;
				}
			}
		});

		$PasswordListingDataGridView | Add-Member -Name:"PSCredentialObjects" -MemberType:NoteProperty -Value:$credentialObjects;
		$PasswordListingDataGridView.DataSource = $dataSource;

		$PasswordListingDataGridView | Write-Output;
	}
}

Function New-Button {
	[CmdletBinding(DefaultParameterSetName = "ClickableButton")]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidatePattern('^[a-zA-Z][\w_]*$')]
		[string]$Name,

		[Parameter(Mandatory = $true)]
		[string]$Text,

		[Parameter(Mandatory = $true, ParameterSetName = "WindowCloseButton")]
		[string]$CommandArg = $Name,

		[Parameter(Mandatory = $false)]
		[bool]$AutoSize = $false,

		[Parameter(Mandatory = $false)]
		[int]$Width = 75,

		[Parameter(Mandatory = $false)]
		[int]$Height = 25,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.Dock]$Dock = [Windows.Forms.Dock]::None,

		[Parameter(Mandatory = $false)]
		[Windows.Forms.AnchorStyles]$Anchor = ([Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right),

		[Parameter(Mandatory = $false)]
		[Windows.Forms.Padding]$Margin = New-Object Windows.Forms.Padding(8, 8, 0, 0),

		[Parameter(Mandatory = $true, ParameterSetName = "ClickableButton")]
		[ScriptBlock]$OnClick
	)

	$Button = New-Object Windows.Forms.Button;
	$Button.Name = $Name;
	$Button.Text = $Text;
	$Button.Width = $Width;
	$Button.Height = $Height;
	$Button.AutoSize = $AutoSize;
	$Button.Dock = $Dock;
	$Button.Anchor = $Anchor;

	if ($PSCmdlet.ParameterSetName -eq "WindowCloseButton") {
		$Button | Add-Member -Name:"_commandArg" -MemberType:NoteProperty -Value:$CommandArg;
		$Button | Add-Member -Name:"CommandArg" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
			if ($this._commandArg -eq $null) {
				$this._commandArg = $this.Name;
			} else {
				if ($this._commandArg -isnot [string]) {
					$this._commandArg = $this._commandArg.ToString();
				}
				if ($this._commandArg.Length -eq 0) { $this._commandArg = $this.Name }
			}

			return $this._commandArg;
		}
		$Button.Add_Click({
			for ($p = $sender.Parent; $p != null; $p = $p.Parent) {
				if ($p -is [Windows.Forms.Form]) {
					$p.PSUserAction = $sender.CommandArg;
					$p.Close();
					break;
				}
			}
		});
	} else {
		$Button.Add_Click($OnClick);
	}
	$AddCredentialButton  | Write-Output;
}

Function Add-TableLayoutPanelChild {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Windows.Forms.TableLayoutPanel]$TableLayoutPanel,

		[Parameter(Mandatory = $true, ValueFromPipelineByName = $true)]
		[Windows.Forms.Control]$Child,

		[Parameter(Mandatory = $true, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 0 }]
		[int]$Column,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 1 }]
		[int]$ColumnSpan = 1,

		[Parameter(Mandatory = $true, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 0 }]
		[int]$Row,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 1 }]
		[int]$RowSpan = 1,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[Windows.Forms.SizeType]$RowSizeType = [Windows.Forms.SizeType]::AutoSize,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 0 }]
		[float]$RowHeight,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[Windows.Forms.SizeType]$ColumnSizeType = [Windows.Forms.SizeType]::AutoSize,

		[Parameter(Mandatory = $false, ValueFromPipelineByName = $true)]
		[ValidateScript({ $_ -ge 0 }]
		[float]$ColumnWidth
	)

	Process {
		$requiredCount = $Column + ($ColumnSpan - 1);

		if ($TableLayoutPanel.ColumnCount -le $requiredCount { $TableLayoutPanel.ColumnCount = $Column + $ColumnSpan }
		for ($r = $TableLayoutPanel.ColumnStyles.Count; $r -lt $requiredCount; $r++) {
			$rootTableLayoutPanel.Columntyles.Add((New-Object Windows.Forms.ColumnStyle)) | Out-Null;
		}

		if ($TableLayoutPanel.ColumnStyles.Count -eq $Row) {
			if ($PSBoundParameters.ContainsKey("ColumnWidth")) {
				$rootTableLayoutPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle($ColumnSizeType, $ColumnWidth)) | Out-Null;
			} else {
				if ($PSBoundParameters.ContainsKey("ColumnSizeType")){
					$rootTableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.ColumnStyle($ColumnSizeType)) | Out-Null;
				} else {
					$rootTableLayoutPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle) | Out-Null;
				}
			}
		} else {
			if ($PSBoundParameters.ContainsKey("ColumnSizeType")) {
				$rootTableLayoutPanel.ColumnStyles[$Column].SizeType = $ColumnSizeType;
			}
			if ($PSBoundParameters.ContainsKey("ColumnWidth")) {
				$rootTableLayoutPanel.ColumnStyles[$Column].Width = $ColumnWidth;
			}
		}

		$requiredCount = $Row + ($RowSpan - 1);

		if ($TableLayoutPanel.RowCount -le $requiredCount { $TableLayoutPanel.RowCount = $Row + $RowSpan }
		for ($r = $TableLayoutPanel.RowStyles.Count; $r -lt $requiredCount; $r++) {
			$rootTableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle)) | Out-Null;
		}

		if ($TableLayoutPanel.RowStyles.Count -eq $Row) {
			if ($PSBoundParameters.ContainsKey("RowHeight")) {
				$rootTableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle($RowSizeType, $RowHeight)) | Out-Null;
			} else {
				if ($PSBoundParameters.ContainsKey("RowSizeType")){
					$rootTableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle($RowSizeType)) | Out-Null;
				} else {
					$rootTableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle) | Out-Null;
				}
			}
		} else {
			if ($PSBoundParameters.ContainsKey("RowSizeType")) {
				$rootTableLayoutPanel.RowStyles[$Row].SizeType = $RowSizeType;
			}
			if ($PSBoundParameters.ContainsKey("RowHeight")) {
				$rootTableLayoutPanel.RowStyles[$Row].Height = $RowHeight;
			}
		}

		$TableLayoutPanel.Controls.Add($Child, $Column, $Row);

		if ($PSBoundParameters.ContainsKey("ColumnSpan") -and $ColumnSpan -gt 1) {
			$TableLayoutPanel.SetRowSpan($Child, $ColumnSpan);
		}

		if ($PSBoundParameters.ContainsKey("RowSpan") -and $RowSpan -gt 1) {
			$TableLayoutPanel.SetColumnSpan($Child, $RowSpan);
		}
	}
}

Function New-PasswordListingWindow {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $false)]
		[ValidatePattern('^[a-zA-Z][\w_]*$')]
		[string]$Name = "LTE_PSCredentialListing",

		[Parameter(Mandatory = $false)]
		[string]$Title = "PS Credential Listing"
	)

	$PasswordListingWindow = New-Object Windows.Forms.Form;
	$PasswordListingWindow.Title = $Title;
	$PasswordListingWindow.Name = $Name;

	$PasswordListingWindow | Add-Member -Name:"_psUserAction" -MemberType:NoteProperty -Value:"";
	$PasswordListingWindow | Add-Member -Name:"PSUserAction" -MemberType:ScriptProperty -PropertyType:[string] -Value:{
		if ($this._psUserAction -eq $null) {
			$this._psUserAction = "";
		} else if ($this._url -isnot [string]) {
			$this._psUserAction = $this._psUserAction.ToString();
		}

		return $this._psUserAction;
	} -SecondValue:{
		if ($_ -eq $null) {
			$this._psUserAction = "";
		} else if ($_ -isnot [string]) {
			$this._psUserAction = $_.ToString();
		} else {
			$this._psUserAction = $_;
		}
	};

	$PasswordListingWindow | Add-Member -Name:"_psActionItem" -MemberType:NoteProperty -Value:$null;
	$PasswordListingWindow | Add-Member -Name:"PSActionItem" -MemberType:ScriptProperty -PropertyType:([Type][PSCustomObject]) -Value:{
		if ($this._psActionItem -ne $null -and ($this._psActionItem -isnot [PSCustomObject] -or (-not ($this._psActionItem | Is-PSCredentialObject)))) {
			$this._psActionItem = $null;
		}

		return $this._psActionItem;
	} -SecondValue:{
		if ($_ -eq $null -or ($_ -is [PSCustomObject] -and ($_ | Is-PSCredentialObject))) {
			$this._psActionItem = $_;
		} else {
			$this._psActionItem = $null;	
		}
	};
	
	$rootTableLayoutPanel = New-Object Windows.Forms.TableLayoutPanel;
	$rootTableLayoutPanel.Name = "rootTableLayoutPanel";
	$rootTableLayoutPanel.AutoSize = $AutoSize;

	$passwordListingDataGridView = Load-PSCredentials | New-PasswordListingDataGridView;

	$addCredentialButton = New-Button -Name:"AddCredentialButton" -Text:"Add" -CommandArg:$Script:AddCommandArg;

	$exitButton = New-Button -Name:"ExitButton" -Text:"Exit" -CommandArg:$Script:ExitCommandArg;

	@(
		@{
			Child = $passwordListingDataGridView;
			Column = 0;
			ColumnSpan = 2;
			ColumnSizeType = [Windows.Forms.SizeType]::Percent;
			ColumnWidth = 100;
			Row = 0;
			RowSizeType = [Windows.Forms.SizeType]::Percent;
			RowHeight = 100;
		}, @{
			Child = $addCredentialButton;
			Column = 0,
			Row = 1;
			RowSizeType = [Windows.Forms.SizeType]::AutoSize;
		}, @{
			Child = $exitButton;
			Column = 1,
			ColumnSizeType = [Windows.Forms.SizeType]::AutoSize;
			Row = 1;
		}
	) | Add-TableLayoutPanelChild $TableLayoutPanel;

	$PasswordListingWindow.Controls.Add($rootTableLayoutPanel);

	$PasswordListingWindow | Write-Output;	
}

Function Invoke-PasswordListingUserActions {
	[CmdletBinding()]
	Param()
	
	$psUserAction = "";

	do {
		$passwordListingWindow = New-PasswordListingWindow;
		$passwordListingWindow.ShowDialog();
		$psUserAction = $passwordListingWindow.PSUserAction;
		$psActionItem = $passwordListingWindow.PSActionItem;
		$passwordListingWindow.Dispose();
		$passwordListingWindow = $null;
		if ($psUserAction -eq $Script:AddCommandArg) {
			Write-Host "Add not implemented";
			continue;
		}
		if ($psUserAction -eq $Script:EditCommandArg) {
			Write-Host "Edit not implemented";
			continue;
		}
		if ($psUserAction -eq $Script:DeleteCommandArg) {
			Write-Host "Edit not implemented";
			continue;
		}
	} while ($psUserAction -ne $Script:ExitCommandArg);
}
