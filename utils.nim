import std/[files, httpclient, osproc, paths, strformat, strutils]
from parse_8086_machine_code import disassemble8086MachineCode


type
  FileNames = tuple
    sourceAsm, sourceBin, disasmAsm, disasmBin: Path


proc fileNames(dir, name: Path): FileNames =
  let
    onlyName = name.changeFileExt("")
  result.sourceAsm = dir / onlyName
  result.sourceBin = dir / name
  result.disasmAsm = dir / Path(&"{onlyName.string}_DISASSEMBLED.asm")
  result.disasmBin = dir / Path(&"{onlyName.string}_DISASSEMBLED")


proc downloadFileFromGit(baseUrl: string, file, dstPath: Path) =
  var
    client: HttpClient = newHttpClient()
  defer:
    client.close()
  let
    response = client.get(&"{baseUrl}/{file.string}")

  if response.code == Http200:
    var
      file: File = open(dst_path.string, fmWrite)
    defer:
      file.close()
    file.write(response.body)
  else:
    echo(&"ERROR: Failed to download '{file.string}' from '{baseUrl}'.")


proc printAsmFile*(filePath: Path) =
  var
    file = open(filePath.string)
  defer:
    file.close()
  echo(filePath.string, ":")
  echo(file.readAll())


proc bytesFromFile(filePath: Path): seq[byte] =
  var
    file = open(filePath.string, fmRead)
  defer:
    file.close()
  result = newSeq[byte](file.getFileSize)
  discard file.readBytes(result, 0, file.getFileSize)


proc assembleFile(src, dst: Path) =
  if execCmd(&"nasm {src.string} -o {dst.string}") != 0:
    echo(&"ERROR: Failed to assemble '{src.string}'.")


proc writeAssemblyFile(dstPath: Path, lines: seq[string]) =
  var
    file = open(dstPath.string, fmWrite)
  defer:
    file.close()

  file.writeLine("bits 16")
  for line in lines:
    file.writeLine(line)


proc areFilesIdentical(path1, path2: Path): bool =
  var
    file1 = open(path1.string, fmRead)
    file2 = open(path2.string, fmRead)
  defer:
    file1.close()
    file2.close()

  let
    size1 = file1.getFileSize()
    size2 = file2.getFileSize()

  if size1 != size2:
    return false

  for _ in 0 ..< size1:
    if file1.readChar() != file2.readChar():
      return false

  return true


proc test_part1_listing*(name: string, verbose: bool=true) =
  let
    gitUrlPrefix = "https://raw.githubusercontent.com/cmuratori/computer_enhance/main/perfaware/part1"
    gitFileName = Path(name)
    data_dir = Path("data")
    (sourceAsm, sourceBin, disasmAsm, disasmBin) = fileNames(dir=data_dir, name=gitFileName)

  # download file from git
  if not fileExists(sourceAsm):
    downloadFileFromGit(baseUrl=gitUrlPrefix, file=gitFileName, dstPath=sourceAsm)

  # show source file content
  if verbose:
    printAsmFile(sourceAsm)

  # assemble source file
  if not fileExists(sourceBin):
    assembleFile(src=sourceAsm, dst=sourceBin)

  # disassemble assembled source file
  let
    assembledSourceBytes = bytesFromFile(sourceBin)
    disassembledInstructions = disassemble8086MachineCode(assembledSourceBytes)
  writeAssemblyFile(dstPath=disasmAsm, lines=disassembledInstructions)


  # assemble disassembled file
  assembleFile(src=disasmAsm, dst=disasmBin)

  # print disassembled instructions
  if verbose:
    echo "Disassembled 8086 Instructions:"
    for asmx86 in disassembledInstructions:
      echo asmx86.toLower
    echo ""

  # compare assembled bytes from source vs disassembled
  if areFilesIdentical(sourceBin, disasmBin):
    echo "SUCCESS"
  else:
    echo "ERROR"
