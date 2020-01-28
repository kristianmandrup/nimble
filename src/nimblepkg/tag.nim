import common, options, strutils, osproc, strscans, re

proc replaceVersionInNimblePkgStr(nimbleStr: string,
    newVersion: string): string =
  let xpr = re"""(version\s+=\s+")(\S+)"""
  let newNimblePkgStr = nimbleStr.replacef(xpr, "$#" & newVersion & "\"")
  newNimblePkgStr

proc execGitCommand*(commandStr: string) =
  let gitCmdStr = "git" & commandStr
  let (errorMsg, errCode) = execCmdEx(gitCmdStr)
  if errCode != 0:
    raise newException(OSError, $errorMsg)

proc commitMsgOrVersion(message: string, version: string) =
  let gitMessage = if message.len > 0: message else: version
  let cmdStr = "commit -m '" & gitMessage & "'"
  execGitCommand(cmdStr)

# Note: currently no way to send a custom commit message for the tag. Always simply uses new version number
proc writeNewVersion(pkg: PackageInfo, newVersion: string,
    message: string = "") =
  let nimbleFilePath = pkg.myPath
  let nimblePkgStr = readFile(nimbleFilePath)
  let newNimblePkgStr = replaceVersionInNimblePkgStr(nimblePkgStr, newVersion)
  writeFile(nimbleFilePath, newNimblePkgStr)
  commitMsgOrVersion(message, newVersion)

proc createVersion(n0, n1, n2: int): string =
  $n0 & "." & $n1 & "." & $n2

proc extractSemVerParts(versionStr: string): tuple[major, minor, patch: int] =
  var
    major, minor, patch: int
  discard versionStr.scanf("$i.$i.$i", major, minor, patch)
  return (major, minor, patch)

proc incVersion(version: string, semVer: tuple[major, minor, patch: int],
optVersion: string): string =
  var (major, minor, patch) = semVer
  var newVersion = ""
  case optVersion:
    of "patch", ".":
      newVersion = createVersion(major, minor, patch + 1)
    of "minor", "m":
      newVersion = createVersion(major, minor + 1, 0)
    of "major", "M":
      newVersion = createVersion(major + 1, 0, 0)
    else:
      newVersion = version

proc incPkgVersion(pkg: PackageInfo, version: string, semVer: tuple[major,
    minor, patch: int], optVersion: string): string =
  let newVersion = incVersion(version, semVer, optVersion)
  if newVersion != version:
    writeNewVersion(pkg, newVersion)

proc calcTagVersion(pkg: PackageInfo, options: Options): string =
  let optVersion = strutils.strip(options.action.tag)
  var version = optVersion
  var pkgVersion = pkg.version
  var semVer = extractSemVerParts(pkgVersion)
  version = incPkgVersion(pkg, version, semVer, optVersion)
  if version.len == 0:
    version = pkgVersion
  return version

proc tagRepo*(pkg: PackageInfo, options: Options) =
  var version = calcTagVersion(pkg, options)
  let tagVersion = "v" & version
  execGitCommand("tag " & tagVersion)
  execGitCommand("push origin master --tags")
