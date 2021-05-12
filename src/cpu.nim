import strutils, random
import rendering

const
  memSize = 4096
  memStart: uint16 = 0x200
  numRegisters = 16
  spriteCols = 8
  screenHeight = 64
  screenWidth = 32

type
  chip8* = ref object
    opcode: uint16
    memory: array[memSize, uint8]
    V: array[numRegisters, uint16]
    index: uint16
    pc: uint16
    stack: seq[uint16]
    gfx: array[screenHeight * screenWidth, bool]

type opFunction = (proc(cpu: var chip8))

# Operation function prototypes
proc clearScreen(cpu: var chip8)
proc subReturn(cpu: var chip8)
proc jmp(cpu: var chip8)
proc runSub(cpu: var chip8)
proc skipEq(cpu: var chip8)
proc skipNotEq(cpu: var chip8)
proc skipXEqY(cpu: var chip8)
proc setReg(cpu: var chip8)
proc addReg(cpu: var chip8)
proc setXEqY(cpu: var chip8)
proc bitwiseOr(cpu: var chip8)
proc bitwiseAnd(cpu: var chip8)
proc bitwiseXor(cpu: var chip8)
proc addRegReg(cpu: var chip8)
proc subRegReg(cpu: var chip8)
proc rightShift(cpu: var chip8)
proc leftShift(cpu: var chip8)
proc subYFromX(cpu: var chip8)
proc skipXNotEqY(cpu: var chip8)
proc setIndex(cpu: var chip8)
proc jmpReg(cpu: var chip8)
proc randNum(cpu: var chip8)
proc draw(cpu: var chip8)

proc getX(opcode: uint16): uint8 =
  result = cast[uint8]((opcode and 0x0F00) shr 8)

proc getY(opcode: uint16): uint8 =
  result = cast[uint8]((opcode and 0x00F0) shr 4)

proc initialize*(cpu: var chip8) =
  cpu.opcode = 0
  #fill(cpu.memory, 0)
  #fill(cpu.V, 0)
  cpu.index = 0
  cpu.pc = memStart
  cpu.stack = @[]

# Load the ROM file at filename into the emulator's memory
proc loadRom*(cpu: var chip8, filename: string): bool =
  var f: File
  try:
    f = open(filename)
  except IOError:
    stderr.write("Bad filepath\n")
    return false
  var buf: array[1, uint8]

  # Init memory starting at memStart until the end of the memory size
  for i in countup(memStart, memSize - 1):
    if readBytes(f, buf, 0, 1) == 0:
      if i == 0:
        stderr.write("Empty file\n")
        return false
      break
    cpu.memory[i] = buf[0]

  return true

# Emulate a clock cycle of the CHIP-8 machine
proc cycle*(cpu: var chip8) =
  var op: opFunction

  # Fetch new opcode
  cpu.opcode = (cast[uint16](cpu.memory[cpu.pc]) shl 8) or (cpu.memory[cpu.pc+1])

  # Decode opcode into function
  case cpu.opcode and 0xF000:
    of 0x0:
      case cpu.opcode and 0x00FF:
        of 0xE0:
          op = clearScreen
        of 0xEE:
          op = subReturn
        else:
          discard
    of 0x1000:
      op = jmp
    of 0x2000:
      op = runSub
    of 0x3000:
      op = skipEq
    of 0x4000:
      op = skipNotEq
    of 0x5000:
      op = skipXEqY
    of 0x6000:
      op = setReg
    of 0x7000:
      op = addReg
    of 0x8000:
      case cpu.opcode and 0x000F:
        of 0x0:
          op = setXEqY
        of 0x1:
          op = bitwiseOr
        of 0x2:
          op = bitwiseAnd
        of 0x3:
          op = bitwiseXor
        of 0x4:
          op = addRegReg
        of 0x5:
          op = subRegReg
        of 0x6:
          op = rightShift
        of 0x7:
          op = subYFromX
        of 0xE:
          op = leftShift
        else:
          discard
    of 0x9000:
      op = skipXNotEqY
    of 0xA000:
      op = setIndex
    of 0xB000:
      op = jmpReg
    of 0xC000:
      op = randNum
    of 0xD000:
      op = draw
    else:
      cpu.pc += 2
      #stderr.write("Not a valid opcode: " & toHex(cpu.opcode) & "\n")

  if not op.isNil:
    op(cpu)

# Clear the graphics screen
proc clearScreen(cpu: var chip8) =
  # Clear graphics
  discard 1 + 1
  cpu.pc += 2

# Return from a subroutine, i.e pop an address of the stack into pc
proc subReturn(cpu: var chip8) =
  cpu.pc = cpu.stack[^1]
  cpu.stack.setLen cpu.stack.len - 1

# Jump to a memory address
proc jmp(cpu: var chip8) =
  cpu.pc = cpu.opcode and 0x0FFF

# Run subroutine at a memory address
proc runSub(cpu: var chip8) =
  # Push current program counter onto the stack
  cpu.stack.add(cpu.pc)
  cpu.pc = cpu.opcode and 0x0FFF

# Skip an instruction if a register equals a constant
proc skipEq(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    value = cpu.opcode and 0x00FF
  
  # Skip next instruction if equal
  if cpu.V[x] == value:
    cpu.pc += 2

  cpu.pc += 2

# Skip and instruction if a register does not equal a constant
proc skipNotEq(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    value = cpu.opcode and 0x00FF

  # Skip next instruction if not equal
  if cpu.V[x] != value:
    cpu.pc += 2

  cpu.pc += 2

# Skip and instruction if two registers are equal
proc skipXEqY(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)

  # Skip next instruction if Vx equals Vy
  if cpu.V[x] == cpu.V[y]:
    cpu.pc += 2

  cpu.pc += 2

proc setReg(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[x] = cpu.opcode and 0x00FF
  cpu.pc += 2

proc addReg(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[x] += cpu.opcode and 0x00FF
  cpu.pc += 2

proc setXEqY(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] = cpu.V[y]
  cpu.pc += 2

proc bitwiseOr(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] = cpu.V[x] or cpu.V[y]
  cpu.pc += 2

proc bitwiseAnd(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] = cpu.V[x] or cpu.V[y]
  cpu.pc += 2

proc bitwiseXor(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] = cpu.V[x] xor cpu.V[y]
  cpu.pc += 2

proc addRegReg(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
    res = cpu.V[x] + cpu.V[y]

  # Check for carry flag
  if res < cpu.V[x] or res < cpu.V[y]:
    cpu.V[0xF] = 1
  else:
    cpu.V[0xF] = 0
  cpu.V[x] += cpu.V[y]
  cpu.pc += 2

proc subRegReg(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] -= cpu.V[y]
  cpu.pc += 2

proc rightShift(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[0xF] = (cpu.V[x] and 0x8000) shr 15
  cpu.V[x] = cpu.V[x] shr 1
  cpu.pc += 2

proc leftShift(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[0xF] = cpu.V[x] and 0x0001
  cpu.V[x] = cpu.V[x] shl 1
  cpu.pc += 2

proc subYFromX(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  cpu.V[x] = cpu.V[y] - cpu.V[x]
  cpu.pc += 2

proc skipXNotEqY(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
  if cpu.V[x] != cpu.V[y]:
    cpu.pc += 2
  cpu.pc += 2

proc setIndex(cpu: var chip8) =
  cpu.index = cpu.opcode and 0x0FFF
  cpu.pc += 2

proc jmpReg(cpu: var chip8) =
  cpu.pc = cpu.V[0] + (cpu.opcode and 0x0FFF)

proc randNum(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    num = cpu.opcode and 0x00FF
  cpu.V[x] = cast[uint16](rand(255)) and num
  cpu.pc += 2

proc draw(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
    n = cpu.opcode and 0x000F
    xVal = cpu.V[x]
    yVal = cpu.V[y]

  # Draw sprite from memory
  for row in countup[uint16](0, n):

    let px = cpu.memory[cpu.index + row]
    for col in countup[uint16](0, spriteCols - 1):
      let val = px and cast[uint8](0x80 shr col)
      if val != 0:
        # Collision detection check
        if cpu.gfx[xVal + row + (yVal + col) * screenHeight]:
          cpu.V[0xF] = 1
        # XOR pixel value
        cpu.gfx[xVal + row + (yVal + col) * screenHeight] = not cpu.gfx[xVal + row + (yVal + col) * screenHeight]

  cpu.pc += 2
