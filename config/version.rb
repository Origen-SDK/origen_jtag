module OrigenJTAG
  MAJOR = 0
  MINOR = 22
  BUGFIX = 2
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
