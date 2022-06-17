#!/bin/bash
php admin/cli/maintenance.php --enable
php admin/cli/upgrade.php
php admin/cli/maintenance.php --disable
