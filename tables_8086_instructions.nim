#[
https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf

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

import std/tables

const OPCODE_MAP* = {
  0b100010'u8: "MOV", # mov_1: Register/memory to/from register
  0b1100011'u8: "MOV", # ?, Immediate to register/memory
  0b1011'u8: "MOV", # ?, "Immediate to register
}.toTable

const DST_MAP* = {
  0b0'u8: "REG specifies SOURCE",
  0b1'u8: "REG specifies DESTINATION",
}.toTable

const WORD_MAP* = {
  0b0'u8: "Byte, 8-bits",
  0b1'u8: "Word, 16-bits",
}.toTable

const MODE_MAP* = {
  0b00'u8: "Memory Mode, no displacement",
  0b01'u8: "Memory Mode, 8-bit displacement",
  0b10'u8: "Memory Mode, 16-bit displacement",
  0b11'u8: "Register Mode",
}.toTable

const REGISTER_MAP* = {
  0b0'u8: {
    0b000'u8: "AL",
    0b001'u8: "CL",
    0b010'u8: "DL",
    0b011'u8: "BL",
    0b100'u8: "AH",
    0b101'u8: "CH",
    0b110'u8: "DH",
    0b111'u8: "BH",
  }.toTable,
  0b1'u8: {
    0b000'u8: "AX",
    0b001'u8: "CX",
    0b010'u8: "DX",
    0b011'u8: "BX",
    0b100'u8: "SP",
    0b101'u8: "BP",
    0b110'u8: "SI",
    0b111'u8: "DI",
  }.toTable,
}.toTable

const MOD00 = {
  0b000'u8: "...",
  0b001'u8: "...",
  0b010'u8: "...",
  0b011'u8: "...",
  0b100'u8: "...",
  0b101'u8: "...",
  0b110'u8: "...",
  0b111'u8: "...",
}.toTable
const MOD01 = {
  0b000'u8: "...",
  0b001'u8: "...",
  0b010'u8: "...",
  0b011'u8: "...",
  0b100'u8: "...",
  0b101'u8: "...",
  0b110'u8: "...",
  0b111'u8: "...",
}.toTable
const MOD10 = {
  0b000'u8: "...",
  0b001'u8: "...",
  0b010'u8: "...",
  0b011'u8: "...",
  0b100'u8: "...",
  0b101'u8: "...",
  0b110'u8: "...",
  0b111'u8: "...",
}.toTable

const REG_MEM_MAP* = {
  0b00'u8: {
    0b0'u8: MOD00,
    0b1'u8: MOD00,
  }.toTable,
  0b01'u8: {
    0b0'u8: MOD01,
    0b1'u8: MOD01,
  }.toTable,
  0b10'u8: {
    0b0'u8: MOD10,
    0b1'u8: MOD10,
  }.toTable,
  0b11'u8: REGISTER_MAP,
}.toTable

