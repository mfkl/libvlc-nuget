#! /bin/bash

version=$1
packageName="VideoLAN.LibVLC.UWP"

mono nuget.exe pack "$packageName".nuspec -Version "$version"