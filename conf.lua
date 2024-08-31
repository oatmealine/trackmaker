function love.conf(t)
  t.identity = 'oatmealine.trackmaker'
  t.appendidentity = true
  t.version = '11.3'

  t.window.title = 'trackmaker'
  t.window.icon = nil
  t.window.width = 1120
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 600
  t.window.minheight = 400
  t.window.vsync = 0
  --t.window.depth = 24

  t.modules.audio = true
  t.modules.data = true
  t.modules.event = true
  t.modules.font = true
  t.modules.graphics = true
  t.modules.image = true
  t.modules.joystick = true
  t.modules.keyboard = true
  t.modules.math = true
  t.modules.mouse = true
  t.modules.physics = true
  t.modules.sound = true
  t.modules.system = true
  t.modules.thread = true
  t.modules.timer = true
  t.modules.touch = false
  t.modules.video = false
  t.modules.window = true

  t.releases = {
    title = 'trackmaker',
    package = 'trackmaker',
    loveVersion = '11.3',
    version = '0.6.2',
    author = 'oatmealine',
    email = 'me@oat.zone',
    description = nil,
    homepage = nil,
    identifier = 'zone.oat.trackmaker',
    excludeFileList = { '^releases/', '^release', '^%.vscode/', '^%.git/', '%.gitignore', '^flake.nix$', '^flake.lock$', '%.dll$', '%.so$', '%.dylib$', '^%.', '^platform/' },
    compile = true
  }
end
