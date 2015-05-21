module JTAG
  MAJOR = 0
  MINOR = 11
  BUGFIX = 0
  DEV = 4

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
