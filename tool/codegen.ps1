#!/usr/bin/env pwsh
# Drift codegen. Run after editing tables.dart or @DataClassName annotations.
# Usage:
#   tool\codegen.ps1            # one-shot build
#   tool\codegen.ps1 -Watch     # rebuild on save

param([switch]$Watch)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if ($Watch) {
    dart run build_runner watch --delete-conflicting-outputs
} else {
    dart run build_runner build --delete-conflicting-outputs
}
