#!/usr/bin/env python3
"""Kitty geninclude for Anserin's saved terminal appearance."""
from pathlib import Path

print('include ' + str(Path.home() / '.config/anserin/terminal/kitty.conf'))
