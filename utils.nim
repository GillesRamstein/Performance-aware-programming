import std/[httpclient, strformat, files, osproc, paths]


proc fileFromGit(uri, filePath: Path) =
  var client: HttpClient
  let url = &"https://raw.githubusercontent.com/{uri.string}"

  try:
    client = newHttpClient()
    let response = client.get(url)
    if response.code == Http200:
      var file: File = open(filePath.string, fmWrite)
      file.write(response.body)
      file.close()
      echo(&"> Downloaded '{url}' to '{filePath.string}'.")
    else:
      echo(&"> Failed to download '{url}'.")

  finally:
    client.close()


proc printFileContent(filePath: Path) =
    var
        file: File
        content: string
    try:
        file = open(filePath.string)
        content = file.readAll()
        file.close()
        echo "\n------------------------ FILE START ------------------------"
        echo content
        echo "------------------------- FILE END -------------------------\n"
    except IOError:
        echo "> Error: Unable to read the file: ", filePath.string


proc bytesFromFile(filePath: Path): seq[byte] =
  var file = open(filePath.string, fmRead)
  defer: file.close()
  result = newSeq[byte](file.getFileSize)
  discard file.readBytes(result, 0, file.getFileSize)


proc loadListingData*(fname: string, part: string): seq[byte] =
  # Set file names
  let gitFile = Path(
    &"cmuratori/computer_enhance/main/perfaware/{part}/{fname}"
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
  result = bytesFromFile(assembledFile)
