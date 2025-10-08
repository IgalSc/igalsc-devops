#!/bin/bash
# This script reads a list of file paths from 'files_to_move.txt',
# removes duplicate entries, and writes the unique file paths to 'unique_files.txt'.
sort files_to_move.txt | uniq > unique_files.txt