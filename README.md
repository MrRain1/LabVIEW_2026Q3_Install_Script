# LabVIEW 2026 Q3 Community Install Script

!!! **DISCLAIMER**: This guide and bash script was written with the help of AI models (Qwen 3.7 and Gemini 3.8 Flash) !!!

- [LabVIEW 2026 Q3 Community Install Script](#labview-2026-q3-community-install-script)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Usage Instructions](#usage-instructions)

## Prerequisites

To install LabView 2026 Q3 on a Linux system a few tools are needed:

- **Docker or Podman**: Distrobox needs a docker engine to run the docker environment
- **Distrobox**: to prop up the linux distro of choice
- (*Optional*) **BoxBuddy**: Useful GUI management tool for Distrobox

## Installation

Clone the repository in a directory of your choice.

## Usage Instructions

The first step is to download the LabVIEW archive containing the repository packages for Linux from National Instruments [download page](https://www.ni.com/en/support/downloads/software-products/download.labview-community.html#607047).

Extract the LabVIEW deb package file for Ubuntu 24.04 and place it in the script directory. You should have something like:

```
labview_script_dir/
├── labview_distrobox_setup.sh
├── ni-labview-*-community_*-ubuntu2404_all.deb
└── README.md
```

The you can start the script:

```bash
bash ./path/to/script/labview_distrobox_setup.sh
```