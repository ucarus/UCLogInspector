# UCLogInspector: HTTP Access Log Analysis

UCLogInspector is an advanced tool for analyzing HTTP access logs of web servers, specializing in identifying attempts to exploit vulnerabilities and uncovering potentially successful attacks. This script is designed to provide a quick and deep insight into security threats, enabling users to effectively recognize the way their server was compromised.

## Introduction

In a world where web servers are constantly exposed to cyber attacks, it is essential to have a tool that can quickly identify and analyze security incidents. UCLogInspector was created to provide web administrators, IT professionals, and security specialists with an efficient means to browse through access logs, identify attempts to exploit known vulnerabilities, and detect successful system breaches.

The script searches the access log for keywords that may indicate attempts to scan for vulnerabilities, such as accessing "/etc/passwd". Upon identifying such attempts, the script determines the IP address of the potential attacker. It then checks whether a POST request from this IP address resulted in an HTTP 200 code, which could signify a successful attack. In this way, UCLogInspector filters log records and provides basic information about whether a vulnerability was discovered during the scan and subsequently exploited.

The aim of UCLogInspector is to enable quick and intuitive searching in log files, provide users with clear information about suspicious activities, and help them respond rapidly to security incidents. This tool is invaluable in situations where a quick analysis of logs is required upon suspicion of a security incident on one of your virtual servers.

## Getting Started

### Prerequisites

Before you begin, ensure you have met the following requirements:
- The script is designed for the Bash shell.
- It is intended to be run in a Linux environment.
- The access log should be in the following format: `77.48.134.52 - - [26/Jan/2024:18:50:15 +0100] "GET /admin/phpMyAdmin/server_import.php HTTP/1.1" 404 17535 "-" "curl/7.74.0"`

Make sure your system meets these prerequisites to utilize the script effectively.

### Installation

To install UCLogInspector, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/ucarus/UCLogInspector.git

2. Run script:
   ```bash
   cd UCLogInspector
   ./ucloginspector.sh
   
