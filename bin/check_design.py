#!/usr/bin/env python

#######################################################################
#######################################################################
## Skeleton copied on March 25, 2020 from nf-core/atacseq
#######################################################################
#######################################################################

from __future__ import print_function

import os
import sys
import requests
import argparse

############################################
############################################
## FUNCTIONS
############################################
############################################

def file_base_name(file_name):
    if '.' in file_name:
        separator_index = file_name.index('.')
        base_name = file_name[:separator_index]
        return base_name
    else:
        return file_name

def path_base_name(path):
    file_name = os.path.basename(path)
    return file_base_name(file_name)

############################################
############################################
## PARSE ARGUMENTS
############################################
############################################

Description = 'Reformat nfcore/slamseq design file and check its contents.'
Epilog = """Example usage: python check_design.py <DESIGN_FILE_IN> <DESIGN_FILE_OUT>"""

argParser = argparse.ArgumentParser(description=Description, epilog=Epilog)

## REQUIRED PARAMETERS
argParser.add_argument('DESIGN_FILE_IN', help="Input design file.")
argParser.add_argument('DESIGN_FILE_OUT', help="Output design file.")
args = argParser.parse_args()

############################################
############################################
## MAIN FUNCTION
############################################
############################################

ERROR_STR = 'ERROR: Please check design file'

HEADER = ['celltype', 'condition', 'control', 'reads']
EXTHEADER = ['celltype', 'condition', 'control', 'reads','name','type','time']

conditions = dict()

with open(args.DESIGN_FILE_IN, 'r') as f:
    header = next(f)

    header = header.rstrip().split("\t")

    if header != HEADER and header != EXTHEADER:
        print("{} header: {} != {}".format(ERROR_STR,','.join(header),','.join(HEADER)))
        sys.exit(1)

    regularDesign = False

    if len(head) == 7:
        regularDesign = True

    for line in f:
        fields = line.rstrip().split("\t")
        celltype = fields[0]
        condition = fields[1]
        control = fields[2]
        reads = fields[3]

        if regularDesign:
            name = fields[4]
            type = fields[5]
            time = fields[6]
        else :
            name = ""
            type = ""
            time = ""

        if name == "":
            name = path_base_name(reads)
        if type == "":
            type = "pulse"
        if time == "":
            time = "0"

        print("\t".join([celltype, condition, control, reads, name, type, time]))
