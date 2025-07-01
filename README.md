# OpenNeuro Selective Downloader
### Universal Tool for Selective Neuroimaging Data Downloads with Flexible Dependencies

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-green.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey.svg)](https://www.microsoft.com/windows)

A complete, automated solution for downloading random subjects from OpenNeuro research datasets without needing to download entire datasets (which can be 50GB+ and take hours). Features flexible dependency management and virtual environment isolation to keep your system clean.

---

## Perfect For Researchers Who Need

- **Sample data for external validation** without downloading entire datasets
- **Specific task data** (e.g., "EyesClosed", "RestingState", "n-back")
- **Quick access to neuroimaging data** without huge time investments
- **Flexible installation options** for different system configurations
- **Clean Python environments** without package conflicts

---

## Key Features

### **Flexible Dependency Management**
- **Multiple installation options** for each dependency
- **User choice** for installation methods (winget, manual, conda, etc.)
- **No forced installations** - you control what gets installed
- **Smart detection** of existing software
- **Graceful handling** of installation failures

### **Virtual Environment Isolation**
- Creates isolated Python environment (`openneuro_research_env`)
- Installs DataLad and dependencies in isolation
- **Keeps your system Python completely clean**
- No package conflicts with existing installations
- Easy to remove if needed

### **Smart Installation Options**

#### Python Installation Options:
- Official Python installer (python.org)
- Windows Package Manager (winget)
- Miniconda/Anaconda (includes conda)
- Manual installation (user choice)

#### Git Installation Options:
- Windows Package Manager (winget)
- Git for Windows (git-scm.com)
- Manual installation

#### git-annex Installation Options:
- Conda install (if conda available)
- Standalone installer
- Install Miniconda first, then git-annex

### **Smart Data Sampling**
- Downloads random subjects with your specified criteria
- Task filtering for specific experimental conditions
- Configurable subject counts and file types
- Preserves original OpenNeuro BIDS filenames for traceability

---

## Quick Start

### Simple One-Command Download
```powershell
# Download 50 random subjects with EyesClosed task from ds005385
.\OpenNeuro_DataLad_Universal_Downloader.ps1 -DatasetId "ds005385" -SubjectCount 50 -TaskFilter "EyesClosed"
