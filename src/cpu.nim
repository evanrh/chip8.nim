import strutils, random
import sdl2
import rendering, keyboard

const
  memSize = 4096
  memStart: uint16 = 0x200
  numRegisters = 16
  spriteCols = 8
  screenHeight = 32
  screenWidth = 64
  timerRate: uint32 = 60
  delayTime: uint32 = 1000'u32 div timerRate

var next_time: uint32 = 0
let fonts: array[0..79, uint8] =
  [0xF0'u8, 0x90, 0x90, 0x90, 0xF0, # 0
  0x20, 0x60, 0x20, 0x20, 0x70, # 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
  0x90, 0x90, 0xF0, 0x10, 0x10, # 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
  0xF0, 0x10, 0x20, 0x40, 0x40, # 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
  0xF0, 0x90, 0xF0, 0x90, 0x90, # A
  0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
  0xF0, 0x80, 0x80, 0x80, 0xF0, # C
  0xE0, 0x90, 0x90, 0x90, 0xE0, # D
  0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
  0xF0, 0x80, 0xF0, 0x80, 0x80] # F

type
  chip8* = ref object
    opcode: uint16
    memory: array[memSize, uint8]
    V: array[numRegisters, uint8]
    index: uint16
    pc: uint16
    stack: seq[uint16]
    gfx: array[screenWidth, array[screenWidth, bool]]
    soundTimer: uint32
    delayTimer: uint32
    screen: ScreenRender

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
proc skipKeyEq(cpu: var chip8)
proc skipKeyNotEq(cpu: var chip8)
proc getDelay(cpu: var chip8)
proc getKey(cpu: var chip8)
proc setDelay(cpu: var chip8)
proc setSound(cpu: var chip8)
proc addToIndex(cpu: var chip8)
proc setIndexFont(cpu: var chip8)
proc storeBCD(cpu: var chip8)
proc regDump(cpu: var chip8)
proc regLoad(cpu: var chip8)

# Get first number from opcode that sends one or two numbers
proc getX(opcode: uint16): uint8 =
  result = uint8((opcode and 0x0F00) shr 8)

# Get second number from opcode that sends two numbers
proc getY(opcode: uint16): uint8 =
  result = uint8((opcode and 0x00F0) shr 4)

# Get remaining frame time to delay
proc time_left(): uint32 =
  let now: uint32 = getTicks()
  if(next_time <= now):
    return 0
  else:
    return next_time - now

# Update cpu timers
proc updateTimers(cpu: var chip8) =
  # Check to keep timers from underflowing
  if (cpu.delayTimer - 1) < cpu.delayTimer:
    cpu.delayTimer = (cpu.delayTimer - 1)
  if (cpu.soundTimer - 1) < cpu.soundTimer:
    cpu.soundTimer = (cpu.soundTimer - 1)
  delay(time_left())
  next_time += delayTime

# Set up fonts in memory
proc setupFonts(cpu: var chip8) =
  for i, px in fonts:
    cpu.memory[i] = px

proc initialize*(cpu: var chip8) =
  cpu.opcode = 0
  #fill(cpu.memory, 0)
  #fill(cpu.V, 0)
  cpu.index = 0
  cpu.pc = memStart
  cpu.stack = @[]
  cpu.delayTimer = uint8(timerRate)
  cpu.soundTimer = 0
  next_time = getTicks() + delayTime
  cpu.setupFonts
  new(cpu.screen)
  if not cpu.screen.init(screenWidth, screenHeight, 10.0):
    quit(QuitFailure)

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
    of 0xE000:
      case cpu.opcode and 0x00FF:
        of 0x009E:
          op = skipKeyEq
        of 0x00A1:
          op = skipKeyNotEq
        else:
          discard
    of 0xF000:
      case cpu.opcode and 0x00FF:
        of 0x0007:
          op = getDelay
        of 0x000A:
          op = getKey
        of 0x0015:
          op = setDelay
        of 0x0018:
          op = setSound
        of 0x001E:
          op = addToIndex
        of 0x0029:
          op = setIndexFont
        of 0x0033:
          op = storeBCD
        of 0x0055:
          op = regDump
        of 0x0065:
          op = regLoad
        else:
          discard
    else:
      cpu.pc += 2
      #stderr.write("Not a valid opcode: " & toHex(cpu.opcode) & "\n")

  if not op.isNil:
    op(cpu)
  # Decrement timers at rate specified above
  cpu.updateTimers()
  if cpu.soundTimer > 0'u32:
    echo "BEEP!"

  cpu.screen.clear
  for i, row in cpu.gfx:
    for j, pixel in row:
      cpu.screen.render(pixel, i, j)
  cpu.screen.show

# Clear the graphics screen
proc clearScreen(cpu: var chip8) =
  for i, row in cpu.gfx:
    for j, col in row:
      cpu.gfx[i][j] = false
  cpu.screen.clear
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
    value: uint8 = uint8(cpu.opcode and 0x00FF)
  
  # Skip next instruction if equal
  if cpu.V[x] == value:
    cpu.pc += 2

  cpu.pc += 2

# Skip and instruction if a register does not equal a constant
proc skipNotEq(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    value: uint8 = uint8(cpu.opcode and 0x00FF)

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
  cpu.V[x] = uint8(cpu.opcode and 0x00FF)
  cpu.pc += 2

proc addReg(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[x] += uint8(cpu.opcode and 0x00FF)
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
  # Borrow check flag
  if cpu.V[y] > cpu.V[x]:
    cpu.V[0xF] = 0
  else:
    cpu.V[0xF] = 1
  cpu.V[x] -= cpu.V[y]
  cpu.pc += 2

proc rightShift(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[0xF] = (cpu.V[x] and 0x80) shr 7
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
  # Borrow check flag
  if cpu.V[x] > cpu.V[y]:
    cpu.V[0xF] = 0
  else:
    cpu.V[0xF] = 1
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
  cpu.pc = uint16(cpu.V[0]) + (cpu.opcode and 0x0FFF)

proc randNum(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    num = cpu.opcode and 0x00FF
  cpu.V[x] = uint8(rand(255)) and uint8 num
  cpu.pc += 2

proc draw(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    y = getY(cpu.opcode)
    n: uint8 = uint8(cpu.opcode and 0x000F)
    xVal = cpu.V[x]
    yVal = cpu.V[y]

  # Draw sprite from memory
  for row in countup[uint8](0, n):

    let px = cpu.memory[cpu.index + row]
    for col in countup[uint8](0, spriteCols - 1):
      let val = px and cast[uint8](0x80 shr col)
      if val != 0:
        # Collision detection check
        try:
          if cpu.gfx[xVal + row][yVal + col]:
            cpu.V[0xF] = 1
          # XOR pixel value
          cpu.gfx[xVal + row][yVal + col] = cpu.gfx[xVal + row][yVal + col] xor true
        except IndexError:
          continue

  cpu.pc += 2

proc skipKeyEq(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    state = checkState(cpu.V[x])

  if state:
    cpu.pc += 2
  cpu.pc += 2

proc skipKeyNotEq(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    state = checkState(cpu.V[x])

  if not state:
    cpu.pc += 2
  cpu.pc += 2

proc getDelay(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[x] = uint8 cpu.delayTimer
  cpu.pc += 2

proc getKey(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.V[x] = getKeyState()
  cpu.pc += 2

proc setDelay(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.delayTimer = cpu.V[x]
  cpu.pc += 2

proc setSound(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.soundTimer = cpu.V[x]
  cpu.pc += 2

proc addToIndex(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.index += cpu.V[x]

proc setIndexFont(cpu: var chip8) =
  let x = getX(cpu.opcode)
  cpu.index = 5'u8 * cpu.V[x]
  cpu.pc += 2

proc storeBCD(cpu: var chip8) =
  let
    x = getX(cpu.opcode)
    i = cpu.index
  cpu.memory[i] = cpu.V[x] div 100;
  cpu.memory[i + 1] = (cpu.V[x] div 10) mod 10
  cpu.memory[i + 2] = (cpu.V[x] mod 100) mod 10
  cpu.pc += 2

proc regDump(cpu: var chip8) =
  let
    i = cpu.index
    x = getX(cpu.opcode)
  for index in countup[uint8](0, x):
    cpu.memory[i + index] = cpu.V[index]
  cpu.pc += 2

proc regLoad(cpu: var chip8) =
  let
    i = cpu.index
    x = getX(cpu.opcode)
  for index in countup[uint8](0, x):
    cpu.V[index] = cpu.memory[i + index]
  cpu.pc += 2
