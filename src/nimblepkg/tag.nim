import common, options, strutils, osproc

proc execGitCommand*(commandStr: string) =
  let gitCmdStr = "git" & commandStr
  let (errorMsg, errCode) = execCmdEx(gitCmdStr)
  if errCode != 0:
    raise newException(OSError, $errorMsg)

proc vNum(numStr: string): int =
  try:
    result = if numStr.len == 0: 0 else: strutils.parseInt(numStr)
  except:
    result = 0

proc createVersion(n0, n1, n2: int): string =
  $n0 & "." & $n1 & "." & $n2

proc tagRepo*(pkg: PackageInfo, options: Options) =
  let optVersion = strutils.strip(options.action.tag)
  var version = optVersion
  var pkgVersion = pkg.version

  let vArr = pkgVersion.split(".")
  var (major, minor, patch) = (vNum(vArr[0]), vNum(vArr[1]), vNum(vArr[2]))

  case optVersion:
    of "patch", ".":
      version = createVersion(major, minor, patch + 1)
    of "minor", "m":
      version = createVersion(major, minor + 1, 0)
    of "major", "M":
      version = createVersion(major + 1, 0, 0)

  if version.len == 0:
    version = pkgVersion
  let tagVersion = "v" & version
  execGitCommand("tag " & tagVersion)
  execGitCommand("push origin master --tags")
