import std/[bitops, sequtils, strformat, strutils, sugar, tables]

# Debug print on/off
const
  VERBOSE: bool = false


# Type Definitions
type
  InstrFieldKind = enum
    Bits_Literal
    Bits_MOD
    Bits_REG
    Bits_RM
    Bits_D
    Bits_W
    Bits_S
    Bits_HasData
    Bits_HasDataW
    Bits_HasAddr
    Bits_HasLabel

  InstrField = object
    kind: InstrFieldKind
    nBits: uint8
    value: uint8

  InstrFormat = object
    kind, dscr: string
    nBytes: uint8
    fields: seq[InstrField]

  DecodeError = object of CatchableError


# Constants
const
  REGISTER = {
    0b000'u16: {0b0'u16: "AL", 0b1'u16: "AX"}.toTable,
    0b001'u16: {0b0'u16: "CL", 0b1'u16: "CX"}.toTable,
    0b010'u16: {0b0'u16: "DL", 0b1'u16: "DX"}.toTable,
    0b011'u16: {0b0'u16: "BL", 0b1'u16: "BX"}.toTable,
    0b100'u16: {0b0'u16: "AH", 0b1'u16: "SP"}.toTable,
    0b101'u16: {0b0'u16: "CH", 0b1'u16: "BP"}.toTable,
    0b110'u16: {0b0'u16: "DH", 0b1'u16: "SI"}.toTable,
    0b111'u16: {0b0'u16: "BH", 0b1'u16: "DI"}.toTable,
  }.toTable

  MOD00 = {
    0b000'u16: "[BX + SI]",
    0b001'u16: "[BX + DI]",
    0b010'u16: "[BP + SI]",
    0b011'u16: "[BP + DI]",
    0b100'u16: "[SI]",
    0b101'u16: "[DI]",
    0b110'u16: "[data]",
    0b111'u16: "[BX]",
  }.toTable

  MOD01 = {
    0b000'u16: "[BX + SI + D8]",
    0b001'u16: "[BX + DI + D8]",
    0b010'u16: "[BP + SI + D8]",
    0b011'u16: "[BP + DI + D8]",
    0b100'u16: "[SI + D8]",
    0b101'u16: "[DI + D8]",
    0b110'u16: "[BP + D8]",
    0b111'u16: "[BX + D8]",
  }.toTable

  MOD10 = {
    0b000'u16: "[BX + SI + D16]",
    0b001'u16: "[BX + DI + D16]",
    0b010'u16: "[BP + SI + D16]",
    0b011'u16: "[BP + DI + D16]",
    0b100'u16: "[SI + D16]",
    0b101'u16: "[DI + D16]",
    0b110'u16: "[BP + D16]",
    0b111'u16: "[BX + D16]",
  }.toTable


# Instruction Definition Helpers
proc B(n: uint8, value: uint8): InstrField = InstrField(kind: Bits_Literal, nBits: n, value: value)
template D(): InstrField = InstrField(kind: Bits_D, nBits: 1)
template W(): InstrField = InstrField(kind: Bits_W, nBits: 1)
template S(): InstrField = InstrField(kind: Bits_S, nBits: 1)
template MOD(): InstrField = InstrField(kind: Bits_MOD, nBits: 2)
template REG(): InstrField = InstrField(kind: Bits_REG, nBits: 3)
template RM(): InstrField = InstrField(kind: Bits_RM, nBits: 3)
template DATA(): InstrField = InstrField(kind: Bits_HasData, value: 1)
template DATAW(): InstrField = InstrField(kind: Bits_HasDataW, value: 1)
template ADDR(): InstrField = InstrField(kind: Bits_HasAddr, value: 1)
template IP_INC8(): InstrField = InstrField(kind: Bits_HasLabel, value: 1)

proc setD(value: uint8): InstrField = InstrField(kind: Bits_D, value: value)
# proc setS(value: uint8): InstrField = InstrField(kind: Bits_S, value: value)

proc instr(kind: string, nBytes: uint8, fields: seq[InstrField], dscr: string): InstrFormat =
  InstrFormat(kind: kind, dscr: dscr, nBytes:nBytes, fields: fields)


# Instruction Definitions
const instructions = @[
  # MOVs:
  # 100010 d w mod reg r/m (disp-lo) (disp-hi)
  instr("mov", 2, @[B(6, 0b100010), D, W, MOD, REG, RM], "reg/mem to/from reg"),
  # 1100011 w mod 000 r/m (disp-lo) (disp-hi) data dataIfW
  instr("mov", 2, @[B(7, 0b1100011), W, MOD, B(3, 0b000), RM, DATA, DATAW], "imd to reg/mem"),
  # 1011 w reg data dataIfW
  instr("mov", 1, @[B(4, 0b1011), W, REG, DATA, DATAW, setD(1)], "imd to reg"),
  # 1010000 w addr-lo addr-hi
  instr("mov", 1, @[B(7, 0b1010000), W, ADDR, setD(1)], "mem to acc"),
  # 1010001 w addr-lo addr-hi
  instr("mov", 1, @[B(7, 0b1010001), W, ADDR], "acc to mem"),

  # ADDs:
  # 000000 d q mod reg r/m (disp-lo) (disp-hi)
  instr("add", 2, @[B(6, 0b000000), D, W, MOD, REG, RM], "reg/mem with reg to either"),
  # 100000 s w mod 000 r/m (disp-lo) (disp-hi) data dataIfSW=01
  instr("add", 2, @[B(6, 0b100000), S, W, MOD, B(3, 0b000), RM, DATA, DATAW], "imd to r/m"),
  # 0000010 w data dataIfW=1
  instr("add", 1, @[B(7, 0b0000010), W, DATA, DATAW, setD(1)], "imd to acc"),

  # SUBs:
  # 001010 d w mod reg r/m (disp-lo) (disp-hi)
  instr("sub", 2, @[B(6, 0b001010), D, W, MOD, REG, RM], "reg/mem and reg from either"),
  # 100000 s w mod 101 r/m (disp-lo) (disp-hi) data dataIfSW=01
  instr("sub", 2, @[B(6, 0b100000), S, W, MOD, B(3, 0b101), RM, DATA, DATAW], "imd from r/m"),
  # 0010110 w data dataIfW=1
  instr("sub", 1, @[B(7, 0b0010110), W, DATA, DATAW, setD(1)], "imd from acc"),

  # CMPs:
  # 001110 d w mod reg r/m (disp-lo) (disp-hi)
  instr("cmp", 2, @[B(6, 0b001110), D, W, MOD, REG, RM], "reg/mem and reg"),
  # 100000 s w mod 111 r/m (disp-lo) (disp-hi) data dataIfSW=1
  instr("cmp", 2, @[B(6, 0b100000), S, W, MOD, B(3, 0b111), RM, DATA, DATAW], "imd with r/m"),
  # 0011110 w data
  # NOTE(gilles): added DATAW even though the manual specifies data to be 8 bits only
  instr("cmp", 1, @[B(7, 0b0011110), W, DATA, DATAW, setD(1)], "imd with acc"),

  # JMPs:
  # JE / JZ
  instr("je", 1, @[B(8, 0b01110100), IP_INC8], "jmp on equal/zero"),
  # JL / JNGE
  instr("jl", 1, @[B(8, 0b01111100), IP_INC8], "jmp on less/not greater or equal"),
  # JLE / JNG
  instr("jle", 1, @[B(8, 0b01111110), IP_INC8], "jmp on less or equal/not greater"),
  # JB / JNAE
  instr("jb", 1, @[B(8, 0b01110010), IP_INC8], "jmp on below/not above or equal"),
  # JBE / JNA
  instr("jbe", 1, @[B(8, 0b01110110), IP_INC8], "jmp on below or equal/not above"),
  # JP / JPE
  instr("jp", 1, @[B(8, 0b01111010), IP_INC8], "jmp on parity/parity even"),
  # JO
  instr("jo", 1, @[B(8, 0b01110000), IP_INC8], "jmp on overflow"),
  # JS
  instr("js", 1, @[B(8, 0b01111000), IP_INC8], "jmp on sign"),
  # JNE / JNZ
  instr("jne", 1, @[B(8, 0b01110101), IP_INC8], "jmp on not equal/not zero"),
  # JNL / JGE
  instr("jnl", 1, @[B(8, 0b01111101), IP_INC8], "jmp on not less/greater or equal"),
  # JNLE /JG
  instr("jnle", 1, @[B(8, 0b01111111), IP_INC8], "jmp on not less or equal/greater"),
  # JNB / JAE
  instr("jnb", 1, @[B(8, 0b01110011), IP_INC8], "jmp on not below/above or equal"),
  # JNBE / JA
  instr("jnbe", 1, @[B(8, 0b01110111), IP_INC8], "jmp on not below or equal/above"),
  # JNP / JPO
  instr("jnp", 1, @[B(8, 0b01111011), IP_INC8], "jmp on not par/par odd"),
  # JNO
  instr("jno", 1, @[B(8, 0b01110001), IP_INC8], "jmp on not overflow"),
  # JNS
  instr("jns", 1, @[B(8, 0b01111001), IP_INC8], "jmp on not sign"),
  # LOOP
  instr("loop", 1, @[B(8, 0b11100010), IP_INC8], "loop CX times"),
  # LOOPZ / LOOPE
  instr("loopz", 1, @[B(8, 0b11100001), IP_INC8], "loop while zero/equal"),
  # LOOPNZ / LOOPNE
  instr("loopnz", 1, @[B(8, 0b11100000), IP_INC8], "loop while not zero/equal"),
  # JCXZ
  instr("jcxz", 1, @[B(8, 0b11100011), IP_INC8], "jmp on CX zero"),
]


proc formatInstruction(s: string): string =
  s.toLower.replace("+ -", "- ").replace(" + 0")


proc concatTwoBytes(low, high: byte): int16 =
  return (high.int16 shl 8) or low.int16


proc extendSign(b: byte): int16 =
  if b.testBit(7):
    result = (0b1111_1111.int16 shl 8) or b.int16
  else:
    result = (0b0000_0000.int16 shl 8) or b.int16


proc parseInstructionFields(bytes: seq[byte], instr: InstrFormat): array[InstrFieldKind, uint16] =
  var
    byteIndex, bitIndex: int
    opCodeShift: int = 0

  for field in instr.fields:

    if field.kind == Bits_Literal:
      # Test if next bits in the byte stream match the op code bits
      if bytes[byteIndex].bitsliced(8-bitIndex-field.nBits.int ..< 8-bitIndex) == field.value:
        result[field.kind] = result[field.kind] shl opCodeShift or field.value
        opCodeShift = field.nBits.int

        if VERBOSE:
          echo ">>> ", "opCodeShift ", result[field.kind].int.toBin(field.nBits)

      else:
        raise newException(DecodeError, "Op code bits do not match")

    else:
      if field.nBits > 0:
        result[field.kind] = bytes[byteIndex].bitsliced(
          8 - bitIndex - field.nBits.int ..< 8 - bitIndex
        ).uint8
      else:
        result[field.kind] = field.value

    bitIndex += field.nBits.int
    if bitIndex >= 8:
      bitIndex = 0
      byteIndex += 1


proc disassemble8086MachineCode*(byteStream: seq[byte]): seq[string] =
  var instrPointer: int = 0

  while instrPointer < byteStream.high:
    let lastIdx = instrPointer

    for instr in instructions:
      let context = byteStream[instrPointer ..< instrPointer + instr.nBytes.int]
      var parsedInstrFields: array[InstrFieldKind, uint16]
      try:
        parsedInstrFields = parseInstructionFields(context, instr)
      except DecodeError:
        continue

      if VERBOSE:
        echo byteStream[instrPointer ..< instrPointer + instr.nBytes.int].mapIt(it.int.toBin(8)).join(" ")
      instrPointer += instr.nBytes.int

      let
        mode = parsedInstrFields[Bits_MOD]
        reg = parsedInstrFields[Bits_REG]
        rm = parsedInstrFields[Bits_RM]
        d = parsedInstrFields[Bits_D] # Instruction SOURCE(d=0) or DESTINATION(d=1) is specified in reg field
        w = parsedInstrFields[Bits_W] # Instruction operates on BYTE(w=0) or WORD(w=1) data
        s = parsedInstrFields[Bits_S] # No sign extenstion / Sign extend 8-bit immediata data to 16 bits if W=1

      var
        operand1, operand2, dataString, dispString: string
        dataBits, dispBits: int16

      let
        instrFields: seq[InstrFieldKind] = instr.fields.map(x => x.kind)
        hasAddr = parsedInstrFields[Bits_HasAddr] == 0b1
        hasDirectAddr = (mode == 0b00) and (rm == 0b110)
        hasDisp8 = (mode == 0b01)
        hasDisp16 = (mode == 0b10) or hasDirectAddr
        hasData = parsedInstrFields[Bits_HasData] == 0b1
        hasDataW = parsedInstrFields[Bits_HasDataW] == 0b1
        wideData = hasDataW and w == 0b1 and s == 0b0
        hasLabel = parsedInstrFields[Bits_HasLabel] == 0b1

      # echo(&"HasDisp8: {hasDisp8}")
      # echo(&"HasDisp16: {hasDisp16}")
      # echo(&"HasDirectAddr: {hasDirectAddr}")
      # echo(&"HasAddr: {hasAddr}")

      # NOTE: order matters: disp appears always before data

      if hasDisp8 or hasLabel:
        dispBits = extendSign(byteStream[instrPointer])
        dispString = $dispBits
        instrPointer += 1

      if hasDisp16:
        dispBits = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
        dispString = $dispBits
        instrPointer += 2

      if hasData:
        if wideData:
          dataBits = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
          dataString = $dataBits
          instrPointer += 2
        else:
          # if s == 0b0:
          #   dataBits = concatTwoBytes(byteStream[instrPointer], 0b00000000'u8)
          # else:
          #   dataBits = extendSign(byteStream[instrPointer])
          dataBits = extendSign(byteStream[instrPointer])
          dataString = $dataBits
          instrPointer += 1

      if hasAddr:
        dataBits = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
        dataString = &"[{dataBits}]"
        instrPointer += 2

      if VERBOSE:
        echo(&"data: ", dataString)
        echo(&"disp: ", dispString)

      # memory to/from register/memory
      if (Bits_REG in instrFields) and (Bits_RM in instrFields):
        if VERBOSE: echo "mem <-> r/m"
        operand1 = REGISTER[reg][w]
        case mode:
          of 0b00:
            if hasDirectAddr:
              operand2 = &"[{dispBits}]"
            else:
              operand2 = MOD00[rm]
          of 0b01:
            operand2 = MOD01[rm].replace("D8", dispString)
          of 0b10:
            operand2 = MOD10[rm].replace("D16", dispString)
          of 0b11:
            operand2 = REGISTER[rm][w]
          else:
            doAssert false, "unreachable"

      # immediate to/from register
      elif Bits_REG in instrFields:
        if VERBOSE: echo "imm <-> reg"
        operand1 = REGISTER[reg][w]
        operand2 = dataString

      # immediate to/from register/memory
      elif Bits_RM in instrFields:
        if VERBOSE: echo "imm <-> r/m"
        operand1 = dataString

        case mode:
          of 0b00:
            if hasDirectAddr:
              operand2 = &"[{dispBits}]"
            else:
              operand2 = MOD00[rm]
          of 0b01:
            operand2 = MOD01[rm].replace("D8", dispString)
          of 0b10:
            operand2 = MOD10[rm].replace("D16", dispString)
          of 0b11:
            operand2 = REGISTER[rm][w]
          else:
            assert false, "unreachable"

        # TODO(gilles): are byte/word keywords always in front of address or can they
        # also be in front if the immediate value?
        if mode != 0b11:
          if w == 0b0:
            operand2 = &"byte {operand2}"
          else:
            operand2 = &"word {operand2}"

      # memory to/from accumulator
      else:
        if VERBOSE: echo "mem -> acc"
        operand1 = {0b0'u16: "AL", 0b1'u16: "AX"}.toTable[w]
        operand2 = dataString

      # Direction
      if d == 0b1:
        var tmp: string
        tmp = operand1
        operand1 = operand2
        operand2 = tmp

      var x86Instruction: string
      if hasLabel:
        x86Instruction = replace(&"{instr.kind} $ + 2 + {dispString}", "+ -", "- ")
      else:
        x86Instruction = formatInstruction(&"{instr.kind} {operand2}, {operand1}")
      result.add(x86Instruction)

      if VERBOSE:
        echo(x86Instruction & "\n")

      break

    if instrPointer == lastIdx:
      let nextByte = byteStream[instrPointer].int.toBin(8)
      raise newException(Exception, &"Failed to detect OP Code in {nextByte}")


when isMainModule:
  from utils import test_part1_listing
  for fname in @[
    "listing_0037_single_register_mov.asm",
    "listing_0038_many_register_mov.asm",
    "listing_0039_more_movs.asm",
    "listing_0040_challenge_movs.asm",
    "listing_0041_add_sub_cmp_jnz.asm",
  ]:
    echo fname
    test_part1_listing(fname, verbose=false)
    echo ""
