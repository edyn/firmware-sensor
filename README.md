# firmware
Code running on the Edyn sensor and the Edyn valve

Getting Started
===============

We should add useful information

Installing Squirrel
===================
http://squirrel-lang.org/#download

Local Development
=================
Install the CLI
https://www.dropbox.com/s/seyd0s7umcv0q61/201407_ide_api.zip?dl=0

###Installing
This guide assumes you’ll be using the developer tools via the PHP wrapper script. After the instructions on installing and using the wrapper scripts, a brief guide to the underlying API is provided so that you may write your own tools if desired.
1. Get the API key from Paul or Dustin
2. Install the php wrappers
 There’s no formal installation script to run, but you’ll need to add the scripts and library to your PATH. Some users may prefer to simply move the ide_api folder to a directory already in the PATH.
 The executables require that the relative path to the files in ide_api/lib be preserved.
```
export PATH=$PATH:<your installed path>/ide_api/bin
```
 Add ide_api/bin to your PATH by adding to your .profile, .bashrc, or equivalent:

###Run the current firmware on a specific device
Takes one argument: device_id
```
run
```

###Open live logs from a device
This command takes one argument, the device ID for the device whose logs you wish to monitor. Control-C to end the logs session.
```
logs
```

Unit Testing
============
We use [framework X] for unit testing.

To run tests, type this command from your terminal:
```
[insert command here]
```

Deployment
==========
Still using the web GUI for now

