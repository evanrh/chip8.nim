import sdl2
import tables

var
  keys = initTable[uint, Scancode]()
  state = getKeyboardState(nil)

keys[0] = SDL_SCANCODE_1
keys[1] = SDL_SCANCODE_2
keys[2] = SDL_SCANCODE_3
keys[3] = SDL_SCANCODE_4
keys[4] = SDL_SCANCODE_Q
keys[5] = SDL_SCANCODE_W
keys[6] = SDL_SCANCODE_E
keys[7] = SDL_SCANCODE_R
keys[8] = SDL_SCANCODE_A
keys[9] = SDL_SCANCODE_S
keys[10] = SDL_SCANCODE_D
keys[11] = SDL_SCANCODE_F
keys[12] = SDL_SCANCODE_Z
keys[13] = SDL_SCANCODE_X
keys[14] = SDL_SCANCODE_C
keys[15] = SDL_SCANCODE_V

proc checkState*(key: uint): bool =
  pumpEvents()
  let val: cint = getKeyFromScancode(keys[key])
  return state[val] == 1

proc getKeyState(): cint =
  var event: Event

  while (addr event).isNil or event.kind != KeyDown:
    discard waitEvent(event)

  return event.keysym.scancode
