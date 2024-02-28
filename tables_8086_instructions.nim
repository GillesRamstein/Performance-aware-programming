import std/tables

const OPCODE_MAP* = {
  "100010": "MOV",
}.toTable

const DST_MAP* = {
  '0': "REG specifies SOURCE",
  '1': "REG specifies DESTINATION",
}.toTable

const WORD_MAP* = {
  '0': "Byte, 8-bits",
  '1': "Word, 16-bits",
}.toTable

const MODE_MAP* = {
  "00": "Memory Mode, no displacement",
  "01": "Memory Mode, 8-bit displacement",
  "10": "Memory Mode, 16-bit displacement",
  "11": "Register Mode",
}.toTable

const REGISTER_MAP* = {
  '0': {
    "000": "AL",
    "001": "CL",
    "010": "DL",
    "011": "BL",
    "100": "AH",
    "101": "CH",
    "110": "DH",
    "111": "BH",
  }.toTable,
  '1': {
    "000": "AX",
    "001": "CX",
    "010": "DX",
    "011": "BX",
    "100": "SP",
    "101": "BP",
    "110": "SI",
    "111": "DI",
  }.toTable,
}.toTable

const MOD00 = {
  "000": "...",
  "001": "...",
  "010": "...",
  "011": "...",
  "100": "...",
  "101": "...",
  "110": "...",
  "111": "...",
}.toTable
const MOD01 = {
  "000": "...",
  "001": "...",
  "010": "...",
  "011": "...",
  "100": "...",
  "101": "...",
  "110": "...",
  "111": "...",
}.toTable
const MOD10 = {
  "000": "...",
  "001": "...",
  "010": "...",
  "011": "...",
  "100": "...",
  "101": "...",
  "110": "...",
  "111": "...",
}.toTable

const REG_MEM_MAP* = {
  "00": {
    '0': MOD00,
    '1': MOD00,
  }.toTable,
  "01": {
    '0': MOD01,
    '1': MOD01,
  }.toTable,
  "10": {
    '0': MOD10,
    '1': MOD10,
  }.toTable,
  "11": REGISTER_MAP,
}.toTable

