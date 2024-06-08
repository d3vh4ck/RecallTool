# Recall Tool

## Introduction
A plethora of information is currently available, specifically in the cybersecurity community, scrutinizing the Windows Recall feature. Recall has been demonstrated to be a serious privacy risk to the public at large if it is released as a feature generally available in GA builds of Windows (and especially enabled by default) and that it has been developed/implemented in an insecure manner. At this point these risks have been demonstrated thoroughly and unequivocally by security researchers.

While Alexander Hagenah has written the excellent and well-written tool [Total Recall](https://github.com/xaitax/TotalRecall/tree/main) (shout out to him for his Python script and for being the first to create a script for accessing and exporting Recall data), the goal of Recall Tool is to be fully Windows native with minimal dependencies. This mimics real-world potential for Recall expoitation using livig-off-the-land techniques and adds to the current evidence showing the (simple!) potential for abuse of Recall.

I'll refrain from re-hashing all of the details regarding the disaster that is Recall since there is enough already publicly available to make the case that is is in fact a 'privacy nightmare'.

Kevin Beaumont ([@GossiTheDog](https://x.com/GossiTheDog/)) has written [a very good article](https://doublepulsar.com/recall-stealing-everything-youve-ever-typed-or-viewed-on-your-own-windows-pc-is-now-possible-da3e12e9465e) on the privacy and security implications of Recall.

## Disclaimer
I do not have an ARM based system or a Windows 11 system. I have an Intel CPU based system with Windows 10. This script was written based on open source information. I re-created the directory, file and database structure using open source information and wrote the script based off of this information. With this warning, it may or may not work as intended. **Use at your own risk!**

You may need to use a different version of SQLite in order for this script to work on Windows 11 with Recall. The version that I used worked with my system, but it may not work with Windows 11/ARM.

If the included SQLite version does not work for you, you can obtain another version for your specific system here: https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki

This script was created for reasearch purposes only. Any unauthorized use of this tool without explicit consent of the system owner and user is strictly prohibited, in alignment with all applicable laws.

## What is Windows Recall
Windows Recall is a feature which, when enabled, takes screenhots of the screen every few seconds, captures keyboard input, then uses AI to parse the images for searchable content, all of which is then stored locally on the system for future reference.

Text from keyboard and screenshot capture is stored in a local database which can be easily and quickly used to find specific data (such as usernames and passwords, banking information, crypto wallet addresses and passwords, you get the idea) for easy access by the user (and/or potential threat actors).

## How Does Recall Tool Work
Since Recall stores all data locally with minimal security controls implemented, it simply gives itself access to the Recall files then accesses and exports the database data and images.

In sequence, this script:
- Verifies that Recall is on the system
- Uses icacls to grant the current user to the Recall directories and files
- Makes a backup of all Recall data to the export directory (stored in a ZIP archive)
- Creates sample data in the database (if specified by the user)
- Searches the databaes for a keyword (default search keyword is 'password')
- Pulls all data from the WindowCapture table
- Saves ald data pulled from the database to CSVs in the export directory

## Command-line Options
- recallpath - path to the Recall database file (string)
- search - keyword to search in the Recall database (string) (default: password)
- exportpath - path to export all data (string)
- createdb - create database tables and populate test data (options: yes)

## Syntax
- .\RecallTool.ps1 [-recallpath PATH] [-search KEYWORD] [-exportpath PATH] [-createdb yes]

## Example Command-lines:
- .\RecallTool.ps1 -search Mypassword01
- .\RecallTool.ps1 -recallpath c:\Users\MyUser\Desktop\recall -search Mypassword01 -exportpath c:\Users\MyUser\Desktop\export
- .\RecallTool.ps1 -createdb yes

## Things To Consider:
- This script cares about directory and file structure
- The ukg.db database file and the ImageStore directory must be in the Recall directory, either natively in the Windows Recall installation or the specified `recallpath` directory
