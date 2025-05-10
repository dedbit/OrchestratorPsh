# Azure Application Certificate Authentication Setup Guide

This guide explains how to set up certificate-based authentication for an Azure application to securely access Key Vault.

## Prerequisites

* An Azure subscription
* Azure CLI installed
* PowerShell 7.0 or later
* OpenSSL (for certificate generation)

## Step 1: Create a Self-Signed Certificate

Refer to the `2-AzureConfiguration.ps1` script for automating the creation of a self-signed certificate. This script includes steps to define parameters, generate the certificate, and export both PFX and CER files.

## Step 2: Register an Azure AD Application

The `2-AzureConfiguration.ps1` script also automates the process of registering an Azure AD application, creating a service principal, and uploading the certificate to the app registration. Follow the script for these steps.

