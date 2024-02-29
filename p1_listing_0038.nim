import std/strutils

from parse_x86_machine_code import parseInstructions
from utils import loadListingData


const PART = "part1"
const FNAME = "listing_0038_many_register_mov.asm"


proc parse_listing_0037_single_register() =
  let bytes = loadListingData(FNAME, PART)

  echo "> Parsed x86 intel assembly:"
  for asmx86 in parseInstructions(bytes):
    echo ">   ", asmx86.toLower


when isMainModule:
  parse_listing_0037_single_register()
