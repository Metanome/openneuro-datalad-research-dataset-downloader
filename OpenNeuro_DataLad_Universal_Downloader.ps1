<#
.SYNOPSIS
    OpenNeuro DataLad Research Dataset Downloader
    Complete setup and selective download tool for scientific datasets

.DESCRIPTION
    This script automatically installs required dependencies and downloads
    random subjects from OpenNeuro datasets using DataLad for efficient
    selective downloading. Designed for researchers who need sample data
    without downloading entire large datasets.

.PARAMETER DatasetId
    OpenNeuro dataset ID (e.g., ds005385)

.PARAMETER SubjectCount
    Number of random subjects to download (default: 75)

.PARAMETER TaskFilter
    Filter for specific task types (e.g., "EyesClosed", "RestingState")

.EXAMPLE
    .\OpenNeuro_DataLad_Universal_Downloader.ps1 -DatasetId "ds005385" -SubjectCount 50 -TaskFilter "EyesClosed"

.NOTES
    Author: OpenNeuro Research Community
    Version: 2.1
    Date: 2025-07-01
    Compatible: Windows 10/11, PowerShell 5.1+
    
    Requirements (flexible installation):
    - Python 3.8+ OR Conda/Miniconda
    - Git
    - DataLad (in virtual environment)
    - git-annex (via conda OR standalone)
    
    Supported Datasets:
    - Any OpenNeuro dataset with LFS files
    - BIDS-compliant neuroimaging datasets
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DatasetId,
    
    [Parameter(Mandatory=$false)]
    [int]$SubjectCount = 75,
    
    [Parameter(Mandatory=$false)]
    [string]$TaskFilter = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFolder = "Downloaded_Research_Data",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDependencyCheck = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

# Script metadata
$ScriptVersion = "2.1"
$ScriptDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$CurrentUser = $env:USERNAME
$CurrentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"

# Virtual environment settings
$VenvName = "openneuro_research_env"
$VenvPath = "$env:USERPROFILE\$VenvName"
$ActivateScript = "$VenvPath\Scripts\Activate.ps1"
$PipExecutable = "$VenvPath\Scripts\pip.exe"
$PythonExecutable = "$VenvPath\Scripts\python.exe"
$DataladExecutable = "$VenvPath\Scripts\datalad.exe"

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║             OpenNeuro DataLad Research Dataset Downloader       ║" -ForegroundColor Cyan
Write-Host "║                   Universal Research Tool v2.1                  ║" -ForegroundColor Cyan
Write-Host "║                    (Virtual Environment Safe)                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔬 Scientific Dataset: $DatasetId" -ForegroundColor Green
Write-Host "👤 User: $CurrentUser" -ForegroundColor Gray
Write-Host "📅 Date: $CurrentDateTime" -ForegroundColor Gray
Write-Host "🎯 Target: $SubjectCount random subjects" -ForegroundColor Yellow
Write-Host "🛡️ Environment: Isolated virtual environment ($VenvName)" -ForegroundColor Magenta
if ($TaskFilter) { Write-Host "🔍 Task Filter: $TaskFilter" -ForegroundColor Yellow }
Write-Host ""

# Global variables
$global:InstallationLog = @()
$global:ErrorLog = @()
$global:SuccessfulInstalls = @()

#region Utility Functions

function Write-LogEntry {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    switch ($Type) {
        "SUCCESS" { Write-Host "✅ $Message" -ForegroundColor Green }
        "ERROR"   { Write-Host "❌ $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
        "INFO"    { Write-Host "ℹ️ $Message" -ForegroundColor Cyan }
        "STEP"    { Write-Host "🔄 $Message" -ForegroundColor White }
        "VENV"    { Write-Host "🐍 $Message" -ForegroundColor Magenta }
        "OPTION"  { Write-Host "🔀 $Message" -ForegroundColor Blue }
        default   { Write-Host "📝 $Message" -ForegroundColor Gray }
    }
    
    $global:InstallationLog += $logEntry
    if ($Type -eq "ERROR") { $global:ErrorLog += $logEntry }
    if ($Type -eq "SUCCESS") { $global:SuccessfulInstalls += $Message }
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-UserChoice {
    param([string]$Message, [array]$Options, [int]$DefaultIndex = 0)
    
    Write-Host $Message -ForegroundColor Yellow
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($i -eq $DefaultIndex) { "→" } else { " " }
        Write-Host "  $marker $($i + 1). $($Options[$i])" -ForegroundColor Cyan
    }
    
    do {
        $choice = Read-Host "`nEnter choice (1-$($Options.Count)) or press Enter for default [$($DefaultIndex + 1)]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            return $DefaultIndex
        }
        if ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $Options.Count) {
            return [int]$choice - 1
        }
        Write-Host "Invalid choice. Please enter a number between 1 and $($Options.Count)." -ForegroundColor Red
    } while ($true)
}

#endregion

#region Flexible Dependency Installation

function Install-PythonFlexible {
    Write-LogEntry "Python not found. Multiple installation options available..." "INFO"
    
    $options = @(
        "Install Python 3.11 via Windows Package Manager (winget)",
        "Install Miniconda (includes Python + conda package manager)",
        "Download Python manually from python.org",
        "I'll install Python myself and re-run the script"
    )
    
    $choice = Get-UserChoice "Choose Python installation method:" $options 1
    
    switch ($choice) {
        0 {  # winget
            Write-LogEntry "Installing Python via Windows Package Manager..." "STEP"
            try {
                if (Test-CommandExists "winget") {
                    winget install --id Python.Python.3.11 -e --source winget --accept-package-agreements --accept-source-agreements
                    $env:PATH = "$env:LOCALAPPDATA\Programs\Python\Python311;$env:LOCALAPPDATA\Programs\Python\Python311\Scripts;" + $env:PATH
                } else {
                    throw "Windows Package Manager (winget) not available"
                }
            } catch {
                Write-LogEntry "winget installation failed: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
        1 {  # Miniconda
            Write-LogEntry "Installing Miniconda (includes Python)..." "STEP"
            return Install-Conda
        }
        2 {  # Manual download
            Write-LogEntry "Opening Python download page..." "INFO"
            Start-Process "https://www.python.org/downloads/"
            Write-Host "Please download and install Python 3.8 or later, then re-run this script." -ForegroundColor Yellow
            return $false
        }
        3 {  # User will install
            Write-Host "Please install Python 3.8+ and re-run this script." -ForegroundColor Yellow
            return $false
        }
    }
    
    # Refresh environment and test
    try { refreshenv 2>$null } catch { }
    Start-Sleep -Seconds 3
    
    if (Test-CommandExists "python") {
        $pythonVersion = python --version
        Write-LogEntry "Python installed successfully: $pythonVersion" "SUCCESS"
        return $true
    } else {
        Write-LogEntry "Python installation completed but python command not found. You may need to restart PowerShell." "WARNING"
        return $false
    }
}

function Install-GitFlexible {
    Write-LogEntry "Git not found. Installation options available..." "INFO"
    
    $options = @(
        "Install Git via Windows Package Manager (winget)",
        "Download Git manually from git-scm.com",
        "I'll install Git myself and re-run the script"
    )
    
    $choice = Get-UserChoice "Choose Git installation method:" $options 0
    
    switch ($choice) {
        0 {  # winget
            Write-LogEntry "Installing Git via Windows Package Manager..." "STEP"
            try {
                if (Test-CommandExists "winget") {
                    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
                } else {
                    throw "Windows Package Manager (winget) not available"
                }
            } catch {
                Write-LogEntry "winget installation failed: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
        1 {  # Manual download
            Write-LogEntry "Opening Git download page..." "INFO"
            Start-Process "https://git-scm.com/download/win"
            Write-Host "Please download and install Git for Windows, then re-run this script." -ForegroundColor Yellow
            return $false
        }
        2 {  # User will install
            Write-Host "Please install Git and re-run this script." -ForegroundColor Yellow
            return $false
        }
    }
    
    # Refresh environment and test
    $env:PATH = "$env:ProgramFiles\Git\bin;$env:ProgramFiles\Git\cmd;" + $env:PATH
    try { refreshenv 2>$null } catch { }
    Start-Sleep -Seconds 3
    
    if (Test-CommandExists "git") {
        Write-LogEntry "Git installed successfully" "SUCCESS"
        return $true
    } else {
        Write-LogEntry "Git installation completed but git command not found. You may need to restart PowerShell." "WARNING"
        return $false
    }
}

function Install-GitAnnexFlexible {
    Write-LogEntry "git-annex not found. Installation options available..." "INFO"
    
    # Check if we have conda available
    $hasConda = Test-CommandExists "conda"
    
    if ($hasConda) {
        $options = @(
            "Install git-annex via conda (recommended)",
            "Download git-annex standalone installer",
            "I'll install git-annex myself and re-run the script"
        )
    } else {
        $options = @(
            "Install Miniconda first, then git-annex",
            "Download git-annex standalone installer", 
            "I'll install git-annex myself and re-run the script"
        )
    }
    
    $choice = Get-UserChoice "Choose git-annex installation method:" $options 0
    
    switch ($choice) {
        0 {  
            if ($hasConda) {
                # Install via conda
                Write-LogEntry "Installing git-annex via conda..." "STEP"
                try {
                    conda install -c conda-forge git-annex -y
                    Start-Sleep -Seconds 5
                } catch {
                    Write-LogEntry "conda installation failed: $($_.Exception.Message)" "ERROR"
                    return $false
                }
            } else {
                # Install Miniconda first
                Write-LogEntry "Installing Miniconda first..." "STEP"
                if (Install-Conda) {
                    Write-LogEntry "Now installing git-annex via conda..." "STEP"
                    try {
                        conda install -c conda-forge git-annex -y
                        Start-Sleep -Seconds 5
                    } catch {
                        Write-LogEntry "conda git-annex installation failed: $($_.Exception.Message)" "ERROR"
                        return $false
                    }
                } else {
                    return $false
                }
            }
        }
        1 {  # Standalone installer
            Write-LogEntry "Opening git-annex download page..." "INFO"
            Start-Process "https://git-annex.branchable.com/install/Windows/"
            Write-Host "Please download and install git-annex standalone, then re-run this script." -ForegroundColor Yellow
            return $false
        }
        2 {  # User will install
            Write-Host "Please install git-annex and re-run this script." -ForegroundColor Yellow
            return $false
        }
    }
    
    # Test installation
    if (Test-CommandExists "git-annex") {
        Write-LogEntry "git-annex installed successfully" "SUCCESS"
        return $true
    } else {
        Write-LogEntry "git-annex installation completed but command not found. You may need to restart PowerShell." "WARNING"
        return $false
    }
}

function Install-Conda {
    Write-LogEntry "Installing Miniconda..." "STEP"
    
    $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
    $installerPath = "$env:TEMP\Miniconda3-latest-Windows-x86_64.exe"
    
    try {
        Write-LogEntry "Downloading Miniconda..." "INFO"
        Invoke-WebRequest -Uri $minicondaUrl -OutFile $installerPath -UseBasicParsing
        
        Write-LogEntry "Installing Miniconda (this may take 5-10 minutes)..." "INFO"
        Start-Process -FilePath $installerPath -ArgumentList "/S", "/AddToPath=1", "/D=$env:USERPROFILE\Miniconda3" -Wait
        
        # Update PATH
        $env:PATH = "$env:USERPROFILE\Miniconda3;$env:USERPROFILE\Miniconda3\Scripts;$env:USERPROFILE\Miniconda3\Library\bin;" + $env:PATH
        
        try { refreshenv 2>$null } catch { }
        Start-Sleep -Seconds 5
        
        if (Test-CommandExists "conda") {
            Write-LogEntry "Miniconda installed successfully" "SUCCESS"
            return $true
        } else {
            throw "Conda command not found after installation"
        }
    } catch {
        Write-LogEntry "Failed to install Miniconda: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        if (Test-Path $installerPath) { Remove-Item $installerPath -Force }
    }
}

#endregion

#region Virtual Environment Management

function Test-VirtualEnvironment {
    Write-LogEntry "Checking virtual environment: $VenvName" "VENV"
    
    if (Test-Path $VenvPath) {
        if (Test-Path $PythonExecutable) {
            Write-LogEntry "Virtual environment found at: $VenvPath" "SUCCESS"
            return $true
        } else {
            Write-LogEntry "Virtual environment directory exists but Python not found" "WARNING"
            return $false
        }
    } else {
        Write-LogEntry "Virtual environment not found" "INFO"
        return $false
    }
}

function New-VirtualEnvironment {
    Write-LogEntry "Creating isolated virtual environment: $VenvName" "VENV"
    
    try {
        # Check if we have Python available
        if (-not (Test-CommandExists "python")) {
            throw "Python not available for virtual environment creation"
        }
        
        # Create virtual environment
        $createResult = python -m venv $VenvPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create virtual environment: $createResult"
        }
        
        # Verify creation
        if (-not (Test-Path $PythonExecutable)) {
            throw "Virtual environment created but Python executable not found"
        }
        
        Write-LogEntry "Virtual environment created successfully" "SUCCESS"
        
        # Upgrade pip in virtual environment
        Write-LogEntry "Upgrading pip in virtual environment..." "VENV"
        $upgradeResult = & $PythonExecutable -m pip install --upgrade pip 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogEntry "Pip upgraded successfully in virtual environment" "SUCCESS"
        } else {
            Write-LogEntry "Warning: Could not upgrade pip: $upgradeResult" "WARNING"
        }
        
        return $true
        
    } catch {
        Write-LogEntry "Failed to create virtual environment: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-PackageInVenv {
    param([string]$PackageName, [string]$ExtraArgs = "")
    
    Write-LogEntry "Installing $PackageName in virtual environment..." "VENV"
    
    try {
        if (-not (Test-Path $PipExecutable)) {
            throw "Virtual environment pip not found at: $PipExecutable"
        }
        
        $installCmd = if ($ExtraArgs) { 
            "& `"$PipExecutable`" install $PackageName $ExtraArgs"
        } else { 
            "& `"$PipExecutable`" install $PackageName"
        }
        
        Write-LogEntry "Executing: $installCmd" "INFO"
        $installResult = Invoke-Expression $installCmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogEntry "$PackageName installed successfully in virtual environment" "SUCCESS"
            return $true
        } else {
            throw "Installation failed: $installResult"
        }
        
    } catch {
        Write-LogEntry "Failed to install $PackageName`: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-PackageInVenv {
    param([string]$PackageName)
    
    try {
        if (-not (Test-Path $PythonExecutable)) {
            return $false
        }
        
        $testResult = & $PythonExecutable -c "import $PackageName; print('$PackageName available')" 2>&1
        return $testResult -like "*available*"
    } catch {
        return $false
    }
}

function Initialize-VirtualEnvironment {
    Write-LogEntry "🐍 Setting up isolated Python virtual environment..." "STEP"
    
    # Check if virtual environment exists and is valid
    if (Test-VirtualEnvironment) {
        Write-LogEntry "Using existing virtual environment" "SUCCESS"
        return $true
    }
    
    # Create new virtual environment
    if (-not (New-VirtualEnvironment)) {
        Write-LogEntry "Failed to create virtual environment" "ERROR"
        return $false
    }
    
    return $true
}

function Install-VirtualEnvironmentPackages {
    Write-LogEntry "Installing research packages in virtual environment..." "VENV"
    
    $packages = @(
        @{ Name = "datalad"; ExtraArgs = "" },
        @{ Name = "requests"; ExtraArgs = "" },
        @{ Name = "tqdm"; ExtraArgs = "" },
        @{ Name = "setuptools"; ExtraArgs = "--upgrade" }
    )
    
    $allInstalled = $true
    
    foreach ($package in $packages) {
        if (-not (Install-PackageInVenv -PackageName $package.Name -ExtraArgs $package.ExtraArgs)) {
            $allInstalled = $false
        }
        
        Start-Sleep -Seconds 2  # Give time between installations
    }
    
    # Verify DataLad installation
    Write-LogEntry "Verifying DataLad installation in virtual environment..." "VENV"
    
    if (Test-PackageInVenv -PackageName "datalad") {
        Write-LogEntry "DataLad successfully installed and verified in virtual environment" "SUCCESS"
    } else {
        Write-LogEntry "DataLad verification failed in virtual environment" "ERROR"
        $allInstalled = $false
    }
    
    return $allInstalled
}

#endregion

#region Flexible Dependency Checking

function Test-AllDependencies {
    Write-LogEntry "🔍 Checking system dependencies with flexible installation options..." "STEP"
    
    $dependencies = @{
        "Python" = @{
            TestFunc = { Test-CommandExists "python" }
            InstallFunc = { Install-PythonFlexible }
            Required = $true
            Alternatives = @("Miniconda/Anaconda", "Official Python installer", "Windows Store Python")
        }
        "Git" = @{
            TestFunc = { Test-CommandExists "git" }
            InstallFunc = { Install-GitFlexible }
            Required = $true
            Alternatives = @("Git for Windows", "GitHub Desktop (includes Git)")
        }
        "VirtualEnvironment" = @{
            TestFunc = { Initialize-VirtualEnvironment }
            InstallFunc = { Initialize-VirtualEnvironment }
            Required = $true
            Alternatives = @("Python venv module (built-in)")
        }
        "DataLad" = @{
            TestFunc = { Test-PackageInVenv -PackageName "datalad" }
            InstallFunc = { Install-VirtualEnvironmentPackages }
            Required = $true
            Alternatives = @("pip install in virtual environment")
        }
        "git-annex" = @{
            TestFunc = { Test-CommandExists "git-annex" }
            InstallFunc = { Install-GitAnnexFlexible }
            Required = $true
            Alternatives = @("conda install", "Standalone installer")
        }
    }
    
    $allPassed = $true
    $installationNeeded = @()
    
    # Check each dependency
    foreach ($dep in $dependencies.Keys) {
        Write-Host "  🔍 Checking $dep..." -ForegroundColor Gray
        
        $isInstalled = & $dependencies[$dep].TestFunc
        
        if ($isInstalled) {
            Write-LogEntry "$dep is ready" "SUCCESS"
        } else {
            $alternatives = $dependencies[$dep].Alternatives -join ", "
            Write-LogEntry "$dep needs installation. Options: $alternatives" "WARNING"
            $installationNeeded += $dep
            if ($dependencies[$dep].Required) {
                $allPassed = $false
            }
        }
    }
    
    if ($allPassed) {
        Write-LogEntry "All dependencies are satisfied!" "SUCCESS"
        return $true
    }
    
    # Install missing dependencies with user choices
    if ($installationNeeded.Count -gt 0 -and -not $SkipDependencyCheck) {
        Write-LogEntry "Setting up missing dependencies with flexible options..." "STEP"
        
        foreach ($dep in $installationNeeded) {
            Write-LogEntry "Setting up $dep with installation options..." "STEP"
            
            try {
                $result = & $dependencies[$dep].InstallFunc
                
                if (-not $result) {
                    Write-LogEntry "User chose to install $dep manually or installation failed" "WARNING"
                    Write-Host "Please install $dep and re-run the script." -ForegroundColor Yellow
                    return $false
                }
                
                # Verify installation
                Start-Sleep -Seconds 3
                if (& $dependencies[$dep].TestFunc) {
                    Write-LogEntry "$dep setup completed successfully" "SUCCESS"
                } else {
                    Write-LogEntry "$dep setup may require PowerShell restart" "WARNING"
                }
            } catch {
                Write-LogEntry "Failed to setup ${dep}: $($_.Exception.Message)" "ERROR"
            }
        }
        
        # Final verification
        Write-LogEntry "Performing final dependency verification..." "STEP"
        Start-Sleep -Seconds 5
        
        $finalCheck = $true
        foreach ($dep in $dependencies.Keys) {
            if ($dependencies[$dep].Required -and -not (& $dependencies[$dep].TestFunc)) {
                Write-LogEntry "$dep is still missing - may require PowerShell restart" "WARNING"
                $finalCheck = $false
            }
        }
        
        if (-not $finalCheck) {
            Write-Host "`n⚠️ Some dependencies may require a PowerShell restart to be recognized." -ForegroundColor Yellow
            Write-Host "If you just installed software, please restart PowerShell and run this script again." -ForegroundColor Yellow
        }
        
        return $finalCheck
    }
    
    return $false
}

#endregion

#region Dataset Download Functions (unchanged but cleaned)

function Get-DatasetInfo {
    param([string]$DatasetId)
    
    Write-LogEntry "Gathering information about dataset $DatasetId..." "STEP"
    
    $datasetInfo = @{
        Id = $DatasetId
        GitUrl = "https://github.com/OpenNeuroDatasets/$DatasetId.git"
        WebUrl = "https://openneuro.org/datasets/$DatasetId"
        LocalPath = $DatasetId
        Valid = $false
    }
    
    try {
        # Test if dataset exists by checking the GitHub URL
        $response = Invoke-WebRequest -Uri $datasetInfo.GitUrl -Method Head -UseBasicParsing -ErrorAction Stop
        $datasetInfo.Valid = $true
        Write-LogEntry "Dataset $DatasetId found and accessible" "SUCCESS"
    } catch {
        Write-LogEntry "Dataset $DatasetId not found or not accessible: $($_.Exception.Message)" "ERROR"
    }
    
    return $datasetInfo
}

function Initialize-DatasetRepository {
    param($DatasetInfo, [string]$OutputPath)
    
    Write-LogEntry "Initializing dataset repository..." "STEP"
    
    try {
        # Clone or update the repository using DataLad from virtual environment
        if (Test-Path $DatasetInfo.LocalPath) {
            Write-LogEntry "Dataset directory exists, updating..." "INFO"
            Set-Location $DatasetInfo.LocalPath
            git pull origin main 2>&1 | Out-Null
        } else {
            Write-LogEntry "Cloning dataset repository (metadata only)..." "INFO"
            
            # Use DataLad from virtual environment
            if (Test-Path $DataladExecutable) {
                $cloneResult = & $DataladExecutable clone $DatasetInfo.GitUrl $DatasetInfo.LocalPath 2>&1
            } else {
                # Fallback to python -m datalad
                $cloneResult = & $PythonExecutable -m datalad clone $DatasetInfo.GitUrl $DatasetInfo.LocalPath 2>&1
            }
            
            if ($LASTEXITCODE -ne 0) {
                throw "DataLad clone failed: $cloneResult"
            }
            
            Set-Location $DatasetInfo.LocalPath
        }
        
        # Verify we're in a valid dataset
        if (-not (Test-Path "dataset_description.json")) {
            throw "Invalid dataset: dataset_description.json not found"
        }
        
        Write-LogEntry "Dataset repository initialized successfully" "SUCCESS"
        return $true
        
    } catch {
        Write-LogEntry "Failed to initialize dataset repository: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-RandomSubjects {
    param([int]$Count, [string]$TaskFilter)
    
    Write-LogEntry "Selecting $Count random subjects..." "STEP"
    
    try {
        # Find all subject directories
        $allSubjects = Get-ChildItem -Directory -Filter "sub-*" | Sort-Object Name
        
        if ($allSubjects.Count -eq 0) {
            throw "No subjects found in dataset"
        }
        
        Write-LogEntry "Found $($allSubjects.Count) subjects in dataset" "INFO"
        
        # Filter subjects based on task if specified
        if ($TaskFilter) {
            Write-LogEntry "Filtering subjects with task: $TaskFilter" "INFO"
            $filteredSubjects = @()
            
            foreach ($subject in $allSubjects) {
                $subjectPath = $subject.FullName
                $taskFiles = Get-ChildItem -Path $subjectPath -Recurse -Filter "*task-$TaskFilter*.edf" -ErrorAction SilentlyContinue
                
                if ($taskFiles.Count -gt 0) {
                    $filteredSubjects += $subject
                }
            }
            
            $allSubjects = $filteredSubjects
            Write-LogEntry "After filtering: $($allSubjects.Count) subjects have $TaskFilter task" "INFO"
        }
        
        if ($allSubjects.Count -eq 0) {
            throw "No subjects found with the specified task filter: $TaskFilter"
        }
        
        # Select random subjects
        $selectedCount = [Math]::Min($Count, $allSubjects.Count)
        $selectedSubjects = $allSubjects | Get-Random -Count $selectedCount
        
        Write-LogEntry "Selected $($selectedSubjects.Count) random subjects for download" "SUCCESS"
        return $selectedSubjects
        
    } catch {
        Write-LogEntry "Failed to select random subjects: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Download-SubjectData {
    param($Subject, [string]$TaskFilter, [string]$OutputPath)
    
    $subjectName = $Subject.Name
    $subjectOutputPath = Join-Path $OutputPath $subjectName
    
    # Create subject output directory
    if (-not (Test-Path $subjectOutputPath)) {
        New-Item -ItemType Directory -Path $subjectOutputPath | Out-Null
    }
    
    $downloadedFiles = @()
    $failedFiles = @()
    
    try {
        # Find EDF files for this subject
        $edfPattern = if ($TaskFilter) { "*task-$TaskFilter*.edf" } else { "*.edf" }
        $edfFiles = Get-ChildItem -Path $Subject.FullName -Recurse -Filter $edfPattern -ErrorAction SilentlyContinue
        
        if ($edfFiles.Count -eq 0) {
            Write-LogEntry "No EDF files found for $subjectName" "WARNING"
            return @{ Downloaded = @(); Failed = @() }
        }
        
        Write-LogEntry "Found $($edfFiles.Count) EDF files for $subjectName" "INFO"
        
        foreach ($edfFile in $edfFiles) {
            $relativePath = $edfFile.FullName.Replace((Get-Location).Path + "\", "").Replace("\", "/")
            $fileName = $edfFile.Name
            $outputFile = Join-Path $subjectOutputPath $fileName
            
            Write-Host "    📄 Downloading: $fileName" -ForegroundColor Gray
            
            try {
                # Check if file is already downloaded
                $currentSize = $edfFile.Length
                
                if ($currentSize -lt 1000) {
                    # File is LFS pointer, download with DataLad from virtual environment
                    if (Test-Path $DataladExecutable) {
                        $getResult = & $DataladExecutable get $relativePath 2>&1
                    } else {
                        $getResult = & $PythonExecutable -m datalad get $relativePath 2>&1
                    }
                    
                    Start-Sleep -Seconds 2
                    $newSize = $edfFile.Length
                } else {
                    $newSize = $currentSize
                }
                
                if ($newSize -gt 100000) {  # File should be > 100KB
                    # Copy to output folder with original filename
                    Copy-Item $edfFile.FullName $outputFile
                    $sizeMB = [Math]::Round($newSize / 1MB, 2)
                    
                    $downloadedFiles += @{
                        OriginalPath = $relativePath
                        FileName = $fileName
                        OutputPath = $outputFile
                        SizeMB = $sizeMB
                    }
                    
                    Write-Host "      ✅ $fileName ($sizeMB MB)" -ForegroundColor Green
                } else {
                    $failedFiles += $fileName
                    Write-Host "      ❌ $fileName (download failed)" -ForegroundColor Red
                }
                
            } catch {
                $failedFiles += $fileName
                Write-Host "      ❌ $fileName (error: $($_.Exception.Message))" -ForegroundColor Red
            }
        }
        
    } catch {
        Write-LogEntry "Error processing subject $subjectName`: $($_.Exception.Message)" "ERROR"
    }
    
    return @{
        Downloaded = $downloadedFiles
        Failed = $failedFiles
    }
}

function Start-SelectiveDownload {
    param([string]$DatasetId, [int]$SubjectCount, [string]$TaskFilter, [string]$OutputFolder)
    
    Write-LogEntry "🚀 Starting selective download process..." "STEP"
    
    # Create main output directory
    $mainOutputPath = "..\$OutputFolder"
    if (-not (Test-Path $mainOutputPath)) {
        New-Item -ItemType Directory -Path $mainOutputPath | Out-Null
        Write-LogEntry "Created output directory: $OutputFolder" "SUCCESS"
    }
    
    # Get dataset info
    $datasetInfo = Get-DatasetInfo -DatasetId $DatasetId
    if (-not $datasetInfo.Valid) {
        Write-LogEntry "Cannot proceed: Dataset $DatasetId is not accessible" "ERROR"
        return $false
    }
    
    # Initialize repository
    if (-not (Initialize-DatasetRepository -DatasetInfo $datasetInfo -OutputPath $mainOutputPath)) {
        Write-LogEntry "Cannot proceed: Failed to initialize dataset repository" "ERROR"
        return $false
    }
    
    # Select random subjects
    $selectedSubjects = Get-RandomSubjects -Count $SubjectCount -TaskFilter $TaskFilter
    if ($selectedSubjects.Count -eq 0) {
        Write-LogEntry "Cannot proceed: No subjects selected" "ERROR"
        return $false
    }
    
    # Download data for each subject
    Write-LogEntry "📥 Starting data download for $($selectedSubjects.Count) subjects..." "STEP"
    
    $downloadResults = @{
        TotalSubjects = $selectedSubjects.Count
        SuccessfulSubjects = 0
        TotalFilesDownloaded = 0
        TotalSizeMB = 0
        SubjectResults = @()
        FailedSubjects = @()
        VirtualEnvironment = $VenvPath
        User = $CurrentUser
        DateTime = $CurrentDateTime
    }
    
    $subjectCounter = 0
    foreach ($subject in $selectedSubjects) {
        $subjectCounter++
        $subjectName = $subject.Name
        
        Write-Host "`n👤 [$subjectCounter/$($selectedSubjects.Count)] Processing: $subjectName" -ForegroundColor White
        
        $subjectResult = Download-SubjectData -Subject $subject -TaskFilter $TaskFilter -OutputPath $mainOutputPath
        
        if ($subjectResult.Downloaded.Count -gt 0) {
            $downloadResults.SuccessfulSubjects++
            $downloadResults.TotalFilesDownloaded += $subjectResult.Downloaded.Count
            
            $subjectSizeMB = ($subjectResult.Downloaded | Measure-Object -Property SizeMB -Sum).Sum
            $downloadResults.TotalSizeMB += $subjectSizeMB
            
            $downloadResults.SubjectResults += @{
                Subject = $subjectName
                FilesDownloaded = $subjectResult.Downloaded.Count
                SizeMB = $subjectSizeMB
                Files = $subjectResult.Downloaded
            }
            
            Write-LogEntry "Subject $subjectName completed: $($subjectResult.Downloaded.Count) files ($([Math]::Round($subjectSizeMB, 2)) MB)" "SUCCESS"
        } else {
            $downloadResults.FailedSubjects += $subjectName
            Write-LogEntry "Subject $subjectName failed: no files downloaded" "ERROR"
        }
        
        # Progress update every 10 subjects
        if ($subjectCounter % 10 -eq 0) {
            Write-Host "`n📊 Progress: $subjectCounter/$($selectedSubjects.Count) subjects processed" -ForegroundColor Magenta
            Write-Host "📈 Downloaded: $($downloadResults.TotalFilesDownloaded) files ($([Math]::Round($downloadResults.TotalSizeMB, 2)) MB)" -ForegroundColor Magenta
        }
    }
    
    # Return to parent directory
    Set-Location ..
    
    # Generate comprehensive report
    Generate-DownloadReport -Results $downloadResults -DatasetId $DatasetId -TaskFilter $TaskFilter -OutputPath $mainOutputPath
    
    return $downloadResults
}

function Generate-DownloadReport {
    param($Results, [string]$DatasetId, [string]$TaskFilter, [string]$OutputPath)
    
    Write-LogEntry "📄 Generating download report..." "STEP"
    
    $reportContent = @"
╔══════════════════════════════════════════════════════════════════╗
║             OpenNeuro DataLad Download Report v2.1              ║
║                    (Virtual Environment Safe)                   ║
╚══════════════════════════════════════════════════════════════════╝

Dataset Information:
- Dataset ID: $DatasetId
- Download Date: $($Results.DateTime)
- User: $($Results.User)
- Task Filter: $(if ($TaskFilter) { $TaskFilter } else { "None (all tasks)" })

Environment Information:
- Virtual Environment: $($Results.VirtualEnvironment)
- Python Packages: Isolated installation (DataLad, requests, tqdm)
- System Python: Unmodified
- Package Isolation: ✅ Clean separation maintained

Download Summary:
- Target Subjects: $($Results.TotalSubjects)
- Successfully Downloaded: $($Results.SuccessfulSubjects) subjects
- Total Files Downloaded: $($Results.TotalFilesDownloaded)
- Total Size: $([Math]::Round($Results.TotalSizeMB, 2)) MB ($([Math]::Round($Results.TotalSizeMB / 1024, 2)) GB)
- Failed Subjects: $($Results.FailedSubjects.Count)

System Information:
- PowerShell Version: $($PSVersionTable.PSVersion)
- OS: $((Get-CimInstance Win32_OperatingSystem).Caption)
- Script Version: $ScriptVersion

Virtual Environment Details:
- Location: $($Results.VirtualEnvironment)
- Python Executable: $($Results.VirtualEnvironment)\Scripts\python.exe
- DataLad Executable: $($Results.VirtualEnvironment)\Scripts\datalad.exe
- Pip Executable: $($Results.VirtualEnvironment)\Scripts\pip.exe

Subject Details:
"@

    foreach ($subjectResult in $Results.SubjectResults) {
        $reportContent += "`n`n$($subjectResult.Subject) ($($subjectResult.FilesDownloaded) files, $([Math]::Round($subjectResult.SizeMB, 2)) MB):"
        foreach ($file in $subjectResult.Files) {
            $reportContent += "`n  - $($file.FileName) ($($file.SizeMB) MB)"
        }
    }
    
    if ($Results.FailedSubjects.Count -gt 0) {
        $reportContent += "`n`nFailed Subjects:"
        foreach ($failedSubject in $Results.FailedSubjects) {
            $reportContent += "`n- $failedSubject"
        }
    }
    
    # Installation log
    if ($global:InstallationLog.Count -gt 0) {
        $reportContent += "`n`nInstallation & Setup Log:"
        foreach ($logEntry in $global:InstallationLog) {
            $reportContent += "`n$logEntry"
        }
    }
    
    # Virtual environment management instructions
    $reportContent += @"

Virtual Environment Management:
- To activate the environment manually:
  & "$($Results.VirtualEnvironment)\Scripts\Activate.ps1"
  
- To use DataLad directly:
  & "$($Results.VirtualEnvironment)\Scripts\datalad.exe" --help
  
- To install additional packages:
  & "$($Results.VirtualEnvironment)\Scripts\pip.exe" install <package_name>
  
- To remove the environment (if needed):
  Remove-Item -Recurse -Force "$($Results.VirtualEnvironment)"
"@
    
    # Save report
    $reportPath = Join-Path $OutputPath "Download_Report_$($DatasetId)_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-LogEntry "Download report saved: $reportPath" "SUCCESS"
    
    # Display summary
    Write-Host "`n╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                     DOWNLOAD COMPLETE                           ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Summary:" -ForegroundColor Yellow
    Write-Host "  🎯 Dataset: $DatasetId" -ForegroundColor Cyan
    Write-Host "  👥 Subjects: $($Results.SuccessfulSubjects)/$($Results.TotalSubjects)" -ForegroundColor Cyan
    Write-Host "  📄 Files: $($Results.TotalFilesDownloaded)" -ForegroundColor Cyan
    Write-Host "  💾 Size: $([Math]::Round($Results.TotalSizeMB, 2)) MB" -ForegroundColor Cyan
    Write-Host "  📁 Location: $OutputPath" -ForegroundColor Cyan
    Write-Host "  🐍 Virtual Env: $($Results.VirtualEnvironment)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "📄 Full report: $reportPath" -ForegroundColor Gray
    Write-Host ""
    
    if ($Results.TotalFilesDownloaded -gt 0) {
        Write-Host "✅ Success! Data is ready for analysis." -ForegroundColor Green
        Write-Host "🐍 Environment: All packages installed in isolated virtual environment" -ForegroundColor Magenta
        Write-Host "📝 Next steps:" -ForegroundColor Green
        Write-Host "   1. Review the downloaded files in: $OutputPath" -ForegroundColor Gray
        Write-Host "   2. Use MATLAB/Python/R to load and analyze the data" -ForegroundColor Gray
        Write-Host "   3. Your system Python remains clean and unmodified" -ForegroundColor Gray
    } else {
        Write-Host "❌ No files were downloaded successfully." -ForegroundColor Red
        Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   1. Check internet connection" -ForegroundColor Gray
        Write-Host "   2. Verify dataset ID is correct" -ForegroundColor Gray
        Write-Host "   3. Try a different task filter" -ForegroundColor Gray
    }
}

#endregion

#region Main Execution

# Main script execution
try {
    # Check and install dependencies with flexible options
    if (-not $SkipDependencyCheck) {
        Write-LogEntry "🔧 Checking dependencies with flexible installation options..." "STEP"
        
        if (-not (Test-AllDependencies)) {
            Write-LogEntry "Some dependencies need manual installation or PowerShell restart." "WARNING"
            Write-Host "`n⚠️ Some dependencies require manual installation or PowerShell restart." -ForegroundColor Yellow
            Write-Host "🔧 Common solutions:" -ForegroundColor Yellow
            Write-Host "   1. Restart PowerShell and run this script again" -ForegroundColor Gray
            Write-Host "   2. Install missing software manually and re-run" -ForegroundColor Gray
            Write-Host "   3. Use -SkipDependencyCheck if you've installed everything" -ForegroundColor Gray
            exit 1
        }
        
        Write-LogEntry "All dependencies satisfied with flexible installation!" "SUCCESS"
    } else {
        Write-LogEntry "Skipping dependency check (--SkipDependencyCheck specified)" "WARNING"
    }
    
    # Start the download process
    $downloadResults = Start-SelectiveDownload -DatasetId $DatasetId -SubjectCount $SubjectCount -TaskFilter $TaskFilter -OutputFolder $OutputFolder
    
    if ($downloadResults -and $downloadResults.TotalFilesDownloaded -gt 0) {
        Write-LogEntry "Download process completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-LogEntry "Download process completed but no files were downloaded" "WARNING"
        exit 1
    }
    
} catch {
    Write-LogEntry "Critical error in main execution: $($_.Exception.Message)" "ERROR"
    Write-LogEntry "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    
    Write-Host "`n💥 Critical Error Occurred" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nPlease check the error details above and try again." -ForegroundColor Yellow
    Write-Host "For support, please provide the error message and your system details." -ForegroundColor Gray
    
    exit 1
}

#endregion
