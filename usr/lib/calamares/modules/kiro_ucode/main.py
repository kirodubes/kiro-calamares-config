#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calamares module for CPU microcode package management.
Detects CPU vendor and removes mismatched microcode packages.
"""

import libcalamares
import subprocess
from libcalamares.utils import target_env_call


class ConfigController:
    """Controller for CPU microcode configuration."""

    def __init__(self):
        """Initialize with target root mount point."""
        self.__root = libcalamares.globalstorage.value("rootMountPoint")

    @property
    def root(self):
        """Get the target root mount point."""
        return self.__root

    def detect_cpu_vendor(self):
        """Detect CPU vendor (AuthenticAMD or GenuineIntel)."""
        try:
            vendor = subprocess.getoutput(
                "hwinfo --cpu | grep Vendor: -m1 | cut -d'\"' -f2"
            ).strip()
            libcalamares.utils.debug(f"Detected CPU vendor: {vendor}")
            return vendor
        except Exception as e:
            libcalamares.utils.warning(f"Failed to detect CPU vendor: {e}")
            return None

    def handle_ucode(self):
        """Remove mismatched microcode package based on detected CPU vendor."""
        vendor = self.detect_cpu_vendor()
        if vendor == "AuthenticAMD":
            libcalamares.utils.debug("Removing intel-ucode for AMD CPU.")
            target_env_call(["pacman", "-R", "intel-ucode", "--noconfirm"])
        elif vendor == "GenuineIntel":
            libcalamares.utils.debug("Removing amd-ucode for Intel CPU.")
            target_env_call(["pacman", "-R", "amd-ucode", "--noconfirm"])
        else:
            libcalamares.utils.debug("Unknown CPU vendor or detection failed.")

    def run(self):
        """Execute microcode configuration."""
        self.handle_ucode()
        return None


def run():
    """Execute CPU microcode configuration."""
    libcalamares.utils.debug("##############################################")
    libcalamares.utils.debug("Start kiro_ucode")
    libcalamares.utils.debug("##############################################\n")

    libcalamares.utils.debug("This module will perform the following operations:")
    libcalamares.utils.debug("  1. Detect CPU vendor (AuthenticAMD or GenuineIntel)")
    libcalamares.utils.debug("  2. Remove mismatched microcode package (amd-ucode or intel-ucode)\n")

    results = {}
    config = ConfigController()
    result = config.run()

    results["Handle microcode"] = "SUCCESS" if result is None else "FAILED"

    libcalamares.utils.debug("##############################################")
    libcalamares.utils.debug("End kiro_ucode - Function Results:")
    for func_name, status in results.items():
        libcalamares.utils.debug(f"  {func_name}: {status}")
    libcalamares.utils.debug("##############################################\n")

    return result
