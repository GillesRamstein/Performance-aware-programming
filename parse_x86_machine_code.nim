import std/[bitops, paths, strformat, strutils, tables]

import tables_8086_instructions


type ASMx86 = string


proc getOpCode(firstByte: byte, opcode_map: Table = OPCODE_MAP): byte =
  # detect opcode
  for opc_bits, opc_name in pairs(opcode_map):
    if (firstByte shr countLeadingZeroBits(opc_bits)) == opc_bits:
      # echo(
      #   &">   Detected opcode '{opc_name}:{opc_bits.int.toBin(8)}' ",
      #   &"in byte '{firstByte.int.toBin(8)}'"
      # )
      result = opc_bits
      break


proc parse_mov_1(bytes: seq[byte], bytesUsed: var int): ASMx86 =
  #
  # MOV: Register/memory to/from register
  # OPCODE: 100010
  #
  # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
  # |   OPCODE  |D|W|MOD| REG | R/M |    DISP-LO    |    DISP-HI    |
  #

  bytesUsed = 2

  let
    byte1  = bytes[0]
    opcode = byte1.masked(0b1111_1100'u8) shr 2
    dst    = byte1.masked(0b0000_0010'u8) shr 1
    word   = byte1.masked(0b0000_0001'u8) shr 0

  let
    byte2    = bytes[1]
    mode     = byte2.masked(0b1100_0000'u8) shr 6
    register = byte2.masked(0b0011_1000'u8) shr 3
    reg_mem  = byte2.masked(0b0000_0111'u8) shr 0

  let verbose = false
  if verbose:
    echo(&"> data binary: {byte1.int.toBin(8)}, {byte2.int.toBin(8)}")
    echo "> OPC: ", opcode.int.toBin(6), " -> ", OPCODE_MAP[opcode]
    echo ">   D:      ", dst, " -> ", DST_MAP[dst]
    echo ">   W:      ", word, " -> ", WORD_MAP[word]
    echo "> MOD:     ", mode.int.toBin(2), " -> ", MODE_MAP[mode]
    echo "> REG:    ", register.int.toBin(3), " -> ", REGISTER_MAP[word][register]
    echo "> R/M:    ", reg_mem.int.toBin(3), " -> ", REG_MEM_MAP[mode][word][reg_mem]

  if mode == 0b00'u8 and reg_mem == 0b110'u8:
    bytesUsed = 4
    let disp_lo = bytes[3]
    let disp_hi = bytes[4]
  
  if mode == 0b01'u8:
    bytesUsed = 3
    let disp_lo = bytes[3]

  if mode == 0b10'u8:
    bytesUsed = 4
    let disp_lo = bytes[3]
    let disp_hi = bytes[4]

  result = OPCODE_MAP[opcode]
  if dst == 0b0'u8:
    result &= &" {REG_MEM_MAP[mode][word][reg_mem]}, {REGISTER_MAP[word][register]}"
  else:
    result &= &" {REGISTER_MAP[word][register]}, {REG_MEM_MAP[mode][word][reg_mem]}"


proc parseInstruction(opCode: byte, bytes: seq[byte], bytesUsed: var int): ASMx86 =
  case opCode:
    of 0b0010_0010'u8:
      # echo("> Parsing instruction 'mov1': register/memory from/to register")
      result = parse_mov_1(bytes, bytesUsed)
    else:
      raise newException(Exception, &"Error: OpCode '{opCode.int.toBin(8)}' is not implemented!")


proc parseInstructions*(bytes: seq[byte]): seq[ASMx86] =
  var
    idx: int = 0
    bytesUsed: int
  while idx < bytes.high:
    bytesUsed = 0
    let nextBytes = bytes[idx .. min(idx + 6, bytes.high)]
    result.add(parseInstruction(getOpCode(nextBytes[0]), nextBytes, bytesUsed))
    idx += bytesUsed


