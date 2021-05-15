import sdl2

type
  ScreenRender* = ref object
    ren: RendererPtr
    window: WindowPtr
    scale: float

proc init*(scr: var ScreenRender, w, h: cint, scale: float): bool =
  scr.window = createWindow("CHIP-8 emulator",
                            SDL_WINDOWPOS_CENTERED,
                            SDL_WINDOWPOS_CENTERED,
                            w * cint scale,
                            h * cint scale,
                            0
                           )
  scr.scale = scale
  if scr.window.isNil:
    stderr.write("Could not create window: " & $getError() & "\n")
    return false
  scr.ren = createRenderer(scr.window, -1, 0)
  if scr.ren.isNil:
    stderr.write("Could not create renderer: " & $getError() & "\n")
    return false
  
  scr.ren.setDrawColor(0, 0, 0, 0)
  return true

proc clear*(scr: var ScreenRender) =
  scr.ren.clear
  
proc render*(scr: var ScreenRender, pixelOn: bool, x, y: cint) =
  var
    prevColor: Color
    pos: Rect
  pos.x = x * cint scr.scale
  pos.y = y * cint scr.scale
  pos.w = 1 * cint scr.scale
  pos.h = 1 * cint scr.scale
  
  if pixelOn:
    scr.ren.getDrawColor(prevColor.r, prevColor.g, prevColor.b, prevColor.a)
    scr.ren.setDrawColor(255, 255, 255)
    scr.ren.fillRect(pos)
    scr.ren.setDrawColor(prevColor.r, prevColor.g, prevColor.b, prevColor.a)

proc show*(scr: var ScreenRender) =
  scr.ren.present
