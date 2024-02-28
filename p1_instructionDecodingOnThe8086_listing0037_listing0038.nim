import std/[files, osproc, paths, strformat, strutils, tables]
from utils import fileFromGit, printFileContent, readBinaryFile
import tables_8086_instructions


proc parse_8086_twoByte_instruction(data: array[2, byte]): string =
  ##[Returns x86 intel syntax assembly language string: <opcode> <destination>, <source>
  ]##
  let byte1 = data[0].int.toBin(8)
  let byte2 = data[1].int.toBin(8)
  let opcode = byte1[0..<6]
  let dst = byte1[6]
  let word = byte1[7]
  let mode = byte2[0..1]
  let register = byte2[2..4]
  let reg_mem = byte2[5..7]

  let verbose = false
  if verbose:
    echo(&"data binary: {byte1}, {byte2}")
    echo " OPC: ", opcode, " -> ", OPCODE_MAP[opcode]
    echo "   D: ", dst, "      -> ", DST_MAP[dst]
    echo "   W: ", word, "      -> ", WORD_MAP[word]
    echo " MOD: ", mode, "     -> ", MODE_MAP[mode]
    echo " REG: ", register, "    -> ", REGISTER_MAP[word][register]
    echo " R/M: ", reg_mem, "    -> ", REG_MEM_MAP[mode][word][reg_mem]

  result = OPCODE_MAP[opcode]
  if dst == '0':
    result.add(&" {REG_MEM_MAP[mode][word][reg_mem]}, {REGISTER_MAP[word][register]}")
  else:
    result.add(&" {REGISTER_MAP[word][register]}, {REG_MEM_MAP[mode][word][reg_mem]}")
  result = result.toLower


proc parse_listing_0037_single_register() =
  # Set file names
  let gitFile = Path(
    "cmuratori/computer_enhance/main/perfaware/part1/listing_0037_single_register_mov.asm"
  )
  let (_, name, ext) = splitFile(gitFile)
  let localFile = Path("data") / name.addFileExt(ext)
  let assembledFile = Path("data") / name

  # Download file from github
  if not fileExists(localFile):
    fileFromGit(gitFile, localFile)

  # Show file content
  printFileContent(localFile)

  # Assemble asm file
  if not fileExists(assembledFile):
    if execCmd(&"nasm {localFile.string} -o {assembledFile.string}") != 0:
      echo("ERROR: Failed to assemble '{localFile.string}'.")

  # Read bytes from assembled file
  let binaryData = readBinaryFile(assembledFile)

  # Parse bytes
  echo "Parsed x86 intel assembly:"
  for twoByteLine in binaryData:
    echo "   ", parse_8086_twoByte_instruction(twoByteLine)


proc parse_listing_0038_many_register() =
  # Set file names
  let gitFile = Path(
    "cmuratori/computer_enhance/main/perfaware/part1/listing_0038_many_register_mov.asm"
  )
  let (_, name, ext) = splitFile(gitFile)
  let localFile = Path("data") / name.addFileExt(ext)
  let assembledFile = Path("data") / name

  # Download file from github
  if not fileExists(localFile):
    fileFromGit(gitFile, localFile)

  # Show file content
  printFileContent(localFile)

  # Assemble asm file
  if not fileExists(assembledFile):
    if execCmd(&"nasm {localFile.string} -o {assembledFile.string}") != 0:
      echo("ERROR: Failed to assemble '{localFile.string}'.")

  # Read bytes from assembled file
  let binaryData = readBinaryFile(assembledFile)

  # Parse bytes
  echo "Parsed x86 intel assembly:"
  for twoByteLine in binaryData:
    echo "   ", parse_8086_twoByte_instruction(twoByteLine)


when isMainModule:
  parse_listing_0037_single_register()
  parse_listing_0038_many_register()


#[

https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf

8086 Machine Instruction Format:

Byte 1          Byte 2          Byte 3  Byte 4  Byte 5  Byte 6
|1 2 3 4 5 6 7 8|1 2 3 4 5 6 7 8|       |       |       |     |
|   OPCODE  |D|W|MOD| REG | R/M |       |       |       |     |

Direction (D) field:
0: Instruction source is specified in REG field
1: Instruction destination is specified in REG field

Word (W) field:
0: byte (8 bits)
1: word (16 bits)

Mode field (MOD) encoding:
MOD
00 Memory Mode, no displacement (except when R/M=110, then 16-bit displacement)
01 Memory Mode, 8-bit displacement
10 Memory Mode, 16-bit displacement
11 Register Mode (no displacement)

Register field (REG) encoding:
REG W0 W1
000 AL AX
001 CL CX
010 DL DX
011 BL BX
100 AH SP
101 CH BP
110 DH SI
111 BH DI

Register/Memory field (R/M) encoding:
  MOD=11  |      Effective Address Calculation         
R/M W0 W1 | R/M MOD=00      MOD=01       MOD=10       
000 AL AX | 000 (BX)+(SI)   (BX)+(SI)+D8 (BX)+(SI)+D16
001 CL CX | 001 (BX)+(DI)   (BX)+(DI)+D8 (BX)+(DI)+D16
010 DL DX | 010 (BP)+(SI)   (BP)+(SI)+D8 (BP)+(SI)+D16
011 BL BX | 011 (BP)+(DI)   (BP)+(DI)+D8 (BP)+(DI)+D16
100 AH SP | 100 (SI)        (SI)+D8      (SI)+D16
101 CH BP | 101 (DI)        (DI)+D8      (DI)+D16
110 DH SI | 110 Direct Addr (BP)+D8      (BP)+D16
111 BH DI | 111 (BX)        (BX)+D8      (BX)+D16


]#
