import std/[bitops, sequtils, strformat, strutils, sugar, tables]

const VERBOSE: bool = false

const
  REGISTER = {
    0b000'u8: {0b0'u8: "AL", 0b1'u8: "AX"}.toTable,
    0b001'u8: {0b0'u8: "CL", 0b1'u8: "CX"}.toTable,
    0b010'u8: {0b0'u8: "DL", 0b1'u8: "DX"}.toTable,
    0b011'u8: {0b0'u8: "BL", 0b1'u8: "BX"}.toTable,
    0b100'u8: {0b0'u8: "AH", 0b1'u8: "SP"}.toTable,
    0b101'u8: {0b0'u8: "CH", 0b1'u8: "BP"}.toTable,
    0b110'u8: {0b0'u8: "DH", 0b1'u8: "SI"}.toTable,
    0b111'u8: {0b0'u8: "BH", 0b1'u8: "DI"}.toTable,
  }.toTable

  MOD00 = {
    0b000'u8: "[BX + SI]",
    0b001'u8: "[BX + DI]",
    0b010'u8: "[BP + SI]",
    0b011'u8: "[BP + DI]",
    0b100'u8: "[SI]",
    0b101'u8: "[DI]",
    0b110'u8: "[data]",
    0b111'u8: "[BX]",
  }.toTable

  MOD01 = {
    0b000'u8: "[BX + SI + D8]",
    0b001'u8: "[BX + DI + D8]",
    0b010'u8: "[BP + SI + D8]",
    0b011'u8: "[BP + DI + D8]",
    0b100'u8: "[SI + D8]",
    0b101'u8: "[DI + D8]",
    0b110'u8: "[BP + D8]",
    0b111'u8: "[BX + D8]",
  }.toTable

  MOD10 = {
    0b000'u8: "[BX + SI + D16]",
    0b001'u8: "[BX + DI + D16]",
    0b010'u8: "[BP + SI + D16]",
    0b011'u8: "[BP + DI + D16]",
    0b100'u8: "[SI + D16]",
    0b101'u8: "[DI + D16]",
    0b110'u8: "[BP + D16]",
    0b111'u8: "[BX + D16]",
  }.toTable


type
  InstrFieldKind = enum
    Bits_Literal
    Bits_MOD,
    Bits_REG,
    Bits_RM,
    Bits_D,
    Bits_W
    Bits_HasData
    Bits_HasDataW
    Bits_HasAddr

  InstrField = object
    kind: InstrFieldKind
    nBits: uint8
    value: uint8

  InstrFormat = object
    kind, dscr: string
    nBytes: uint8
    fields: seq[InstrField]


proc B(n: uint8, value: uint8): InstrField = InstrField(kind: Bits_Literal, nBits: n, value: value)
template D(): InstrField = InstrField(kind: Bits_D, nBits: 1)
template W(): InstrField = InstrField(kind: Bits_W, nBits: 1)
template MOD(): InstrField = InstrField(kind: Bits_MOD, nBits: 2)
template REG(): InstrField = InstrField(kind: Bits_REG, nBits: 3)
template RM(): InstrField = InstrField(kind: Bits_RM, nBits: 3)
template DATA(): InstrField = InstrField(kind: Bits_HasData, value: 1)
template DATAW(): InstrField = InstrField(kind: Bits_HasDataW, value: 1)
template ADDR(): InstrField = InstrField(kind: Bits_HasAddr, value: 1)

proc setD(value: uint8): InstrField = InstrField(kind: Bits_D, value: value)

proc instr(kind: string, nBytes: uint8, fields: seq[InstrField], dscr: string): InstrFormat =
  InstrFormat(kind: kind, dscr: dscr, nBytes:nBytes, fields: fields)


const instructions = @[
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


proc bitsMatchOpCode(bits: byte, op: InstrField): bool =
  bits.bitsliced(8-op.nBits.int ..< 8) == op.value


proc parseInstructionFields(bytes: seq[byte], instr: InstrFormat): array[InstrFieldKind, uint8] =
  const N = 16
  let instrBits: uint16 = if bytes.len == 1: bytes[0].uint16 shl 8 else: concatTwoBytes(bytes[1], bytes[0]).uint16
  if VERBOSE: echo instrBits.int.toBin(16)
  var bitIndex: int = instr.fields[0].nBits.int
  for field in instr.fields[1 .. ^1]:
    if field.nBits > 0:
      # parsed values
      result[field.kind] = instrBits.bitsliced(N - bitIndex - field.nBits.int ..< N - bitIndex).uint8
      bitIndex += field.nBits.int
    else:
      # configured values
      result[field.kind] = field.value


proc parseInstructions*(byteStream: seq[byte]): seq[string] =
  var instrPointer: int = 0

  while instrPointer < byteStream.high:
    let lastIdx = instrPointer
    # echo "Instruction Pointer: ", instrPointer

    for instr in instructions:
      if not bitsMatchOpCode(byteStream[instrPointer], instr.fields[0]):
        continue

      let
        opCode = instr.kind
        parsedInstrFields = parseInstructionFields(
          byteStream[instrPointer ..< instrPointer + instr.nBytes.int], instr
        )
      instrPointer += instr.nBytes.int

      let
        mode = parsedInstrFields[Bits_MOD]
        reg = parsedInstrFields[Bits_REG]
        rm = parsedInstrFields[Bits_RM]
        d = parsedInstrFields[Bits_D]
        w = parsedInstrFields[Bits_W]


      var
        operand1, operand2, dataString, dispString: string
        dataBits, dispBits: int16

      let
        instrFields: seq[InstrFieldKind] = instr.fields.map(x => x.kind)
        hasDisp8 = (mode == 0b01)
        hasDisp16 = (mode == 0b10) or (mode == 0b00 and rm == 0b110)
        hasData = parsedInstrFields[Bits_HasData] == 0b1
        # hasDataW = parsedInstrFields[Bits_HasDataW] == 0b1
        hasAddr = parsedInstrFields[Bits_HasAddr] == 0b1
        hasDirectAddr = (mode == 0b00) and (rm == 0b110)

      if hasDisp8:
        dispBIts = extendSign(byteStream[instrPointer])
        dispString = $dispBits
        instrPointer += 1

      if hasDisp16:
        dispBIts = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
        dispString = $dispBits
        instrPointer += 2

      if hasData:
        if w == 0b0:
          dataBits = extendSign(byteStream[instrPointer])
          dataString = $dataBits
          instrPointer += 1
        else:
          dataBits = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
          dataString = $dataBits
          instrPointer += 2

      if hasAddr:
        dataBits = concatTwoBytes(byteStream[instrPointer], byteStream[instrPointer + 1])
        dataString = &"[{dataBits}]"
        instrPointer += 2

      if hasDirectAddr:
        dataString =  &"[{dispBits}]"

      if VERBOSE:
        echo(&"data: ", dataString)
        echo(&"disp: ", dispString)

      # memory to/from register/memory
      if (Bits_REG in instrFields) and (Bits_RM in instrFields):
        if VERBOSE: echo "mem <-> r/m"
        operand1 = REGISTER[reg][w]
        case mode:
          of 0b00:
            if rm == 0b110:
              operand2 = dataString
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

      # immediate to/from register
      elif Bits_REG in instrFields:
        if VERBOSE: echo "imm <-> reg"
        operand1 = REGISTER[reg][w]
        operand2 = dataString

      # immediate to/from register/memory
      elif Bits_RM in instrFields:
        if VERBOSE: echo "imm <-> r/m"
        if w == 0b0:
          operand1 = &"byte {dataString}"
        else:
          operand1 = &"word {dataString}"

        case mode:
          of 0b00:
            if rm == 0b110:
              operand2 = dataString
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

      # memory to/from accumulator
      else:
        if VERBOSE: echo "mem -> acc"
        operand1 = {0b0'u8: "AL", 0b1'u8: "AX"}.toTable[w]
        operand2 = dataString

      # Direction
      if d == 0b1:
        var tmp: string
        tmp = operand1
        operand1 = operand2
        operand2 = tmp

      let x86Instruction: string = formatInstruction(&"{opcode} {operand2}, {operand1}")
      if VERBOSE: echo x86Instruction
      result.add(x86Instruction)
      break

    if instrPointer == lastIdx:
      let nextByte = byteStream[instrPointer].int.toBin(8)
      raise newException(Exception, &"Failed to detect OP Code in {nextByte}")


when isMainModule:
  from utils import loadListingData
  for fname in @[
    "listing_0037_single_register_mov.asm",
    "listing_0038_many_register_mov.asm",
    "listing_0039_more_movs.asm",
    "listing_0040_challenge_movs.asm",
  ]:
    let bytes = loadListingData(fname, "part1")
    if VERBOSE:
      discard parseInstructions(bytes)
    else:
      echo "> Parsed x86 intel assembly:"
      for asmx86 in parseInstructions(bytes):
        echo asmx86.toLower
