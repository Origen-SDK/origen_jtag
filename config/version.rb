module OrigenJTAG
  MAJOR = 0
  MINOR = 21
  BUGFIX = 1
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
