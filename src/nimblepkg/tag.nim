import common, options, strutils, osproc, strscans
import bump

proc writeNewVersion(newVersion: string, message: seq[string] = @[]) =
  discard bump.bump(manual = newVersion, message = message)

proc execGitCommand*(commandStr: string) =
  let gitCmdStr = "git" & commandStr
  let (errorMsg, errCode) = execCmdEx(gitCmdStr)
  if errCode != 0:
    raise newException(OSError, $errorMsg)

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
  if newVersion.len > 0:
    writeNewVersion(newVersion)
    result = newVersion
  else:
    result = version

proc calcTagVersion(pkg: PackageInfo, options: Options): string =
  let optVersion = strutils.strip(options.action.tag)
  var version = optVersion
  var pkgVersion = pkg.version
  var semVer = extractSemVerParts(pkgVersion)
  version = incVersion(version, semVer, optVersion)
  if version.len == 0:
    version = pkgVersion
  return version

proc tagRepo*(pkg: PackageInfo, options: Options) =
  var version = calcTagVersion(pkg, options)
  let tagVersion = "v" & version
  execGitCommand("tag " & tagVersion)
  execGitCommand("push origin master --tags")
