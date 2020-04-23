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

with open(args.DESIGN_FILE_IN, 'r') as f:
    header = next(f)

    colNumbers = header.rstrip.split("\t")

    if header != HEADER and header != EXTHEADER:
        print("{} header: {} != {}".format(ERROR_STR,','.join(header),','.join(HEADER)))
        sys.exit(1)

    regularDesign = False

    if len(colNumbers) == 7:
        regularDesign = True

    print(header)
    print(regularDesign)
