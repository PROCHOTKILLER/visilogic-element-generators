Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipPath = "dokumentacja\Visilogic_projekt_HMI_displays.vld"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)
$udbPath = Join-Path $tempDir "HMIBufferColorPages.udb"

$connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$udbPath;"
$conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
$conn.Open()

$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT [ID], [DisplayID], [Type], [VarType], [Text], [Xs], [Ys], [Dx], [Dy] FROM [HMI_Elements]"
$reader = $cmd.ExecuteReader()
while ($reader.Read()) {
    Write-Host ("ID: " + $reader["ID"] + " Disp: " + $reader["DisplayID"] + " Type: " + $reader["Type"] + " VarType: " + $reader["VarType"] + " Text: " + $reader["Text"] + " Pos: " + $reader["Xs"] + "," + $reader["Ys"] + " " + $reader["Dx"] + "x" + $reader["Dy"])
}
$reader.Close()

$cmd2 = $conn.CreateCommand()
$cmd2.CommandText = "SELECT DISTINCT [Type], [VarType] FROM [HMI_Elements]"
$reader2 = $cmd2.ExecuteReader()
Write-Host "`nDistinct Types:"
while ($reader2.Read()) {
    Write-Host ("Type: " + $reader2[0] + " VarType: " + $reader2[1])
}
$reader2.Close()

$conn.Close()
Remove-Item -Recurse -Force $tempDir
