import std/[httpclient, strformat, paths]


proc fileFromGit*(uri, filePath: Path) =
  var client: HttpClient
  let url = &"https://raw.githubusercontent.com/{uri.string}"

  try:
    client = newHttpClient()
    let response = client.get(url)
    if response.code == Http200:
      var file: File = open(filePath.string, fmWrite)
      file.write(response.body)
      file.close()
      echo(&"Downloaded '{url}' to '{filePath.string}'.")
    else:
      echo(&"Failed to download '{url}'.")

  finally:
    client.close()


proc printFileContent*(filePath: Path) =
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
        echo "Error: Unable to read the file: ", filePath.string


proc readBinaryFile*(filePath: Path): seq[array[2 ,byte]] =
  var
    file: File
    line: array[2, byte]
  try:
    file = open(filePath.string, fmRead)
    var i: int = 0
    while i < file.getFileSize():
      discard file.readBytes(line, 0 , 2)
      result.add(line)
      i += 2
    file.close()
  except IOError:
    echo "Error: Unable to read the file: ", filePath.string
