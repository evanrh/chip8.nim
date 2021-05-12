import sdl2

type
  ScreenRender = ref object
    ren: RendererPtr
    window: WindowPtr


