import std/[bitops, paths, strformat, strutils, tables]

import tables_8086_instructions


const DEBUG: bool = false

type ASMx86 = string


proc concatBytes(high, low: byte): int16 =
  return (high.int16 shl 8) or low.int16


proc extendSign(b: byte): int16 =
  if b.testBit(7):
    result = (0b1111_1111.int16 shl 8) or b.int16
  else:
    result = (0b0000_0000.int16 shl 8) or b.int16


proc fixPlusMinus(s: string): string =
  result = s.replace("+ -", "- ")


proc fixPlusZero(s: string): string =
  result = s.replace(" + 0", "")


proc getOpCode(firstByte: byte, opcode_map: Table = OPCODE_MAP): byte =
  for opc_bits, opc_name in pairs(opcode_map):
    if (firstByte shr countLeadingZeroBits(opc_bits)) == opc_bits:
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

    byte2    = bytes[1]
    mode     = byte2.masked(0b1100_0000'u8) shr 6
    register = byte2.masked(0b0011_1000'u8) shr 3
    reg_mem  = byte2.masked(0b0000_0111'u8) shr 0

  var disp: int16

  if mode == 0b00'u8 and reg_mem == 0b110'u8:
    bytesUsed = 4
    disp = concatBytes(bytes[3], bytes[2])
  
  elif mode == 0b01'u8:
    bytesUsed = 3
    disp = extendSign(bytes[2])

  elif mode == 0b10'u8:
    bytesUsed = 4
    disp = concatBytes(bytes[3], bytes[2])

  result = OPCODE_MAP[opcode]
  let x = REG_MEM_MAP[mode][word][reg_mem].replace("data", $disp)
  if dst == 0b0'u8:
    result &= &" {x}, {REGISTER_MAP[word][register]}"
  else:
    result &= &" {REGISTER_MAP[word][register]}, {x}"
  result = result.fixPlusMinus.fixPlusZero


proc parse_mov_2(bytes: seq[byte], bytesUsed: var int): ASMx86 =
  #
  # MOV: Immediate to register/memory
  # OPCODE: 1100011
  #
  # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
  # |    OPCODE   |W|MOD|0 0 0| R/M |    DISP-LO    |    DISP-HI    |     DATA      |  DATA if W=1  |
  #
  bytesUsed = 2

  let
    byte1  = bytes[0]
    opcode = byte1.masked(0b1111_1110'u8) shr 1
    word   = byte1.masked(0b0000_0001'u8) shr 0

    byte2    = bytes[1]
    mode     = byte2.masked(0b1100_0000'u8) shr 6
    reg_mem  = byte2.masked(0b0000_0111'u8) shr 0

  var
    data, disp: int16
    prefix: string

  case mode:
    of 0b00'u8:
      if reg_mem == 0b110'u8:
        disp = concatBytes(bytes[3], bytes[2])
        if word == 0b0'u8:
          bytesUsed = 5
          data = extendSign(bytes[4])
          prefix = "byte"
        else:
          bytesUsed = 6
          data = concatBytes(bytes[5], bytes[4])
          prefix = "word"

      else:
        if word == 0b0'u8:
          bytesUsed = 3
          data = extendSign(bytes[2])
          prefix = "byte"
        else:
          bytesUsed = 4
          data = concatBytes(bytes[3], bytes[2])
          prefix = "word"
  
    of 0b01'u8:
      disp = bytes[2].int16
      if word == 0b0'u8:
        bytesUsed = 4
        data = extendSign(bytes[3])
        prefix = "byte"
      else:
        bytesUsed = 5
        data = concatBytes(bytes[4], bytes[3])
        prefix = "word"

    of 0b10'u8:
      disp = concatBytes(bytes[3], bytes[2])
      if word == 0b0'u8:
        bytesUsed = 5
        data = extendSign(bytes[4])
        prefix = "byte"
      else:
        bytesUsed = 6
        data = concatBytes(bytes[5], bytes[4])
        prefix = "word"

    of 0b11'u8:
      if word == 0b0'u8:
        bytesUsed = 3
        data = extendSign(bytes[2])
        prefix = "byte"
      else:
        bytesUsed = 4
        data = concatBytes(bytes[3], bytes[2])
        prefix = "word"

    else:
      raise newException(Exception, "unreachable")
      

  result = OPCODE_MAP[opcode]
  let x = REG_MEM_MAP[mode][word][reg_mem].replace("data", $disp)
  result &= &" {x}, {prefix} {data}"
  result = result.fixPlusMinus.fixPlusZero


proc parse_mov_3(bytes: seq[byte], bytesUsed: var int): ASMx86 =
  #
  # MOV: Immediate to register
  # OPCODE: 1100011
  #
  # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
  # |OPCODE |W| REG |     DATA      |  DATA if W=1  |
  #
  let
    byte1    = bytes[0]
    opcode   = byte1.masked(0b1111_0000'u8) shr 4
    word     = byte1.masked(0b0000_1000'u8) shr 3
    register = byte1.masked(0b0000_0111'u8) shr 0

  result = OPCODE_MAP[opcode]
  if word == 0b0'u8:
    bytesUsed = 2
    result &= &" {REGISTER_MAP[word][register]}, {extendSign(bytes[1])}"
  else:
    bytesUsed = 3
    result &= &" {REGISTER_MAP[word][register]}, {concatBytes(bytes[2], bytes[1])}"
  result = result.fixPlusMinus.fixPlusZero


proc parse_mov_4(bytes: seq[byte], bytesUsed: var int): ASMx86 =
  #
  # MOV: Memory to accumulator
  # OPCODE: 1010000
  #
  # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
  # |   OPCODE    |W|    ADDR-LO    |    ADDR-HI    |
  #
  bytesUsed = 3

  let
    byte1    = bytes[0]
    opcode   = byte1.masked(0b1111_1110'u8) shr 1
    word     = byte1.masked(0b0000_0001'u8) shr 0
    address  = concatBytes(bytes[2], bytes[1])

  result = OPCODE_MAP[opcode]
  if word == 0b0'u8:
    result &= &" al, [{address}]"
  else:
    result &= &" ax, [{address}]"
  result = result.fixPlusMinus.fixPlusZero


proc parse_mov_5(bytes: seq[byte], bytesUsed: var int): ASMx86 =
  #
  # MOV: Accumulator to memory
  # OPCODE: 1010001
  #
  # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
  # |   OPCODE    |W|    ADDR-LO    |    ADDR-HI    |
  #
  bytesUsed = 3

  let
    byte1    = bytes[0]
    opcode   = byte1.masked(0b1111_1110'u8) shr 1
    word     = byte1.masked(0b0000_0001'u8) shr 0
    address  = concatBytes(bytes[2], bytes[1])

  result = OPCODE_MAP[opcode]
  if word == 0b0'u8:
    result &= &" [{address}], al"
  else:
    result &= &" [{address}], ax"
  result = result.fixPlusMinus.fixPlusZero


proc parseInstruction(opCode: byte, bytes: seq[byte], bytesUsed: var int): ASMx86 =
  case opCode:
    of 0b0010_0010'u8:
      result = parse_mov_1(bytes, bytesUsed)
    of 0b0110_0011'u8:
      result = parse_mov_2(bytes, bytesUsed)
    of 0b0000_1011'u8:
      result = parse_mov_3(bytes, bytesUsed)
    of 0b0101_0000'u8:
      result = parse_mov_4(bytes, bytesUsed)
    of 0b0101_0001'u8:
      result = parse_mov_5(bytes, bytesUsed)
    else:
      raise newException(Exception, &"Error: OpCode '{opCode.int.toBin(8)}' is not implemented!")


proc parseInstructions*(bytes: seq[byte]): seq[ASMx86] =
  var
    idx: int = 0
    bytesUsed: int
  while idx < bytes.high:
    bytesUsed = 0
    let top = min(idx + 6, bytes.high)
    let nextBytes = bytes[idx .. top]
    let opcode = getOpCode(nextBytes[0])
    let instr = parseInstruction(opcode, nextBytes, bytesUsed)

    if DEBUG:
      echo "opcode: ", opcode.int.toBin(8)
      echo instr, " (", bytesUsed, ")"
      for i in 0 ..< bytesUsed:
        echo "  ", nextBytes[i].int.toBin(8)

    result.add(instr)
    idx += bytesUsed
