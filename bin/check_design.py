#!/usr/bin/env python

#######################################################################
#######################################################################
## Copied on March 25, 2020 from nf-core/atacseq
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

with open(args.DESIGN_FILE_IN, 'r') as f:
    header = next(f)
    print(header)
