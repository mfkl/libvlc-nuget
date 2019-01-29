#! /bin/bash

version=$1
packageName="VideoLAN.LibVLC.WindowsRT"

mono nuget.exe pack "$packageName".nuspec -Version "$version"