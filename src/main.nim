# System imports
import os

# User defined package imports
import cpu

proc main() =

  if paramCount() != 1:
    stderr.write("Please input a single input file to emulate\n")
    quit(QuitFailure)

  var emulator: chip8
  new(emulator)

  emulator.initialize()
  if not emulator.loadRom(paramStr(1)):
    quit(QuitFailure)

  var
    running: bool = true
  while(running):
    emulator.cycle()

main()
