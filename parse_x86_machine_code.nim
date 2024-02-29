import std/[bitops, paths, strformat, strutils, tables]

import tables_8086_instructions


type ASMx86 = string


proc concatBytes(high, low: byte): uint16 =
  return (high.uint16 shl 8) or low


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

  var disp: uint16

  if mode == 0b00'u8 and reg_mem == 0b110'u8:
    bytesUsed = 4
    disp = concatBytes(bytes[3], bytes[2])
  
  elif mode == 0b01'u8:
    bytesUsed = 3
    disp = bytes[2]

  elif mode == 0b10'u8:
    bytesUsed = 4
    disp = concatBytes(bytes[3], bytes[2])

  result = OPCODE_MAP[opcode]
  let x = REG_MEM_MAP[mode][word][reg_mem].replace("data", $disp)
  if dst == 0b0'u8:
    result &= &" {x}, {REGISTER_MAP[word][register]}"
  else:
    result &= &" {REGISTER_MAP[word][register]}, {x}"


# proc parse_mov_2(bytes: seq[byte], bytesUsed: var int): ASMx86 =
#   #
#   # MOV: Immediate to register/memory
#   # OPCODE: 1100011
#   #
#   # |7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|7 6 5 4 3 2 1 0|
#   # |    OPCODE   |W|MOD|0 0 0| R/M |    DISP-LO    |    DISP-HI    |     DATA      |  DATA if W=1  |
#   #

#   bytesUsed = 2

#   let
#     byte1  = bytes[0]
#     opcode = byte1.masked(0b1111_1110'u8) shr 1
#     word   = byte1.masked(0b0000_0001'u8) shr 0

#     byte2    = bytes[1]
#     mode     = byte2.masked(0b1100_0000'u8) shr 6
#     register = 0b0000_0000'u8
#     reg_mem  = byte2.masked(0b0000_0111'u8) shr 0

#   var
#     disp_lo, disp_hi: byte
#     data1, data2: byte

#   if mode == 0b00'u8 and reg_mem == 0b110'u8:
#     bytesUsed = 5
#     disp_lo = bytes[2]
#     disp_hi = bytes[3]
#     data1 = bytes[4]
#     if word == 0b1'u8:
#       bytesUsed = 6
#       data2 = bytes[5]
  
#   if mode == 0b01'u8:
#     bytesUsed = 4
#     disp_lo = bytes[2]
#     data1 = bytes[3]
#     if word == 0b1'u8:
#       bytesUsed = 5
#       data2 = bytes[4]

#   if mode == 0b10'u8:
#     bytesUsed = 5
#     disp_lo = bytes[2]
#     disp_hi = bytes[3]
#     data1 = bytes[4]
#     if word == 0b1'u8:
#       bytesUsed = 6
#       data2 = bytes[5]

#   result = OPCODE_MAP[opcode]
#   result &= &" {REG_MEM_MAP[mode][word][reg_mem]}, {REGISTER_MAP[word][register]}"


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
    result &= &" {REGISTER_MAP[word][register]}, {bytes[1]}"
  else:
    bytesUsed = 3
    result &= &" {REGISTER_MAP[word][register]}, {concatBytes(bytes[2], bytes[1])}"


proc parseInstruction(opCode: byte, bytes: seq[byte], bytesUsed: var int): ASMx86 =
  case opCode:
    of 0b10_0010'u8:
      # echo "move1"
      result = parse_mov_1(bytes, bytesUsed)
    # of 0b110_0011'u8:
    #   # echo "move2"
    #   result = parse_mov_2(bytes, bytesUsed)
    of 0b1011'u8:
      # echo "move3"
      result = parse_mov_3(bytes, bytesUsed)
    else:
      raise newException(Exception, &"Error: OpCode '{opCode.int.toBin(8)}' is not implemented!")


proc parseInstructions*(bytes: seq[byte]): seq[ASMx86] =
  var
    idx: int = 0
    bytesUsed: int
  while idx < bytes.high:
    bytesUsed = 0
    let top = min(idx + 6, bytes.high)
    # echo idx, "..", top
    let nextBytes = bytes[idx .. top]
    let instr = parseInstruction(getOpCode(nextBytes[0]), nextBytes, bytesUsed)
    # echo instr, "  (", bytesUsed, " bytes used)"
    result.add(instr)
    idx += bytesUsed


