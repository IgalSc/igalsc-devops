#!/bin/sh
# Define variables
USER='{USER_EMAIL}'
# get the shared drives list
gam print teamdrives > shared_drives.csv

# grant permissions to the shared drives
gam redirect stdout ./AddOrganizer.txt multiprocess \
    redirect stderr stdout csv ./shared_drives.csv \
    gam add drivefileacl teamdriveid "~id" user ${USER} role organizer