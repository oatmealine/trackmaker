# trackmaker

![](docs/screenshot-1.png)

Heavily work-in-progress GUI chart editor for
[EX-XDRiVER](https://store.steampowered.com/app/2636020/EXXDRiVER/) written with
[LÖVE](https://love2d.org/).

## Run

Download a [release](https://github.com/oatmealine/trackmaker/releases), and
follow the instructions:

- **Windows**: Download and extract `trackmaker-win64-${ver}.zip`, then run
`trackmaker.exe`.
- **macOS**: Download and extract `trackmaker-mac-${ver}.zip`. Either drag into
    your Applications folder or run as usual.

    If you get an error along the lines of
    "the developer cannot be verified", see: [Open a Mac app from an unknown
    developer](https://support.apple.com/en-gb/guide/mac-help/mh40616/mac)

    macOS builds should work on 10.11+. Apple Silicon remains untested as I do
    not have a machine to test the builds on.
- **Linux**: Download and extract `trackmaker-linux-${ver}.zip`, and install
[LÖVE](https://love2d.org) from your distribution's package manager (`love2d` in
most repos). Run `start.sh`.

## Develop

0. Clone the repository:

    ```sh
    git clone https://github.com/oatmealine/trackmaker
    ```

1. Get [nfd](https://github.com/Vexatos/nativefiledialog/tree/master/lua) w/
[luarocks](https://luarocks.org):
  
    ```sh
    luarocks install https://raw.githubusercontent.com/Vexatos/nativefiledialog/master/lua/nfd-scm-1.rockspec --local
    ```

2. Drop it in the same folder as this repository:

    ```sh
    # for instance, on linux:
    cp ~/.luarocks/lib/lua/5.1/nfd.so ./
    ```

3. Run with [LÖVE](https://love2d.org/):

    ```sh
    love .
    ```

## Contributing

Feel free to contribute anything you'd like to see. I'm following a pretty
specific vision with the editor, but **contributions are always appreciated**
and I'll always try my best to work out how to fit them well. Thank you!

## Credits

This project would not be possible without these projects:

- [LÖVE](https://love2d.org/) _(zlib + [dependency licenses](https://github.com/love2d/love/blob/6807e54bab3a080b7ac3f75ac8c02d1c00fd8f67/license.txt))_
- [json.lua](https://github.com/rxi/json.lua) _(licensed under [MIT](https://github.com/rxi/json.lua/blob/dbf4b2dd2eb7c23be2773c89eb059dadd6436f94/LICENSE))_
- [classic](https://github.com/rxi/classic) _(licensed under [MIT](https://github.com/rxi/classic/blob/e5610756c98ac2f8facd7ab90c94e1a097ecd2c6/LICENSE))_
- [Vexatos](https://github.com/Vexatos)'s fork of
[nativefiledialog](https://github.com/Vexatos/nativefiledialog) _(licensed under [zlib](https://github.com/Vexatos/nativefiledialog/blob/bea4560b9269bdc142fef946ccd8682450748958/LICENSE))_
- [deep](https://github.com/Nikaoto/deep), slightly tweaked _(licensed under [MIT](https://github.com/Nikaoto/deep/blob/a948f7724a3772fbb5d539ed06d828e64eceaa7b/LICENSE))_
- [Cirno's Perfect Math Library](https://github.com/excessive/cpml) _([Mixed license](https://github.com/excessive/cpml/blob/eb209f6d9111625d8e0e8a32dafb4a0aed12a84e/LICENSE.md))_
- [sort.lua](https://github.com/1bardesign/batteries/blob/master/sort.lua) from [batteries](https://github.com/1bardesign/batteries) _(licensed under MIT)_
- [Inter](https://rsms.me/inter/) _(licensed under [OFL](https://openfontlicense.org))_
- Assets, code from [EX-XDRiVER](https://xdrv.team/) _(all rights reserved, used with permission)_
- [Lönn](https://github.com/CelestialCartographers/Loenn/): A lot of the
nativefiledialog handling code is stolen from them. Thank you very much!

And these people:

- [tari](https://github.com/tari-cat), [riley](https://github.com/rilegoat), and
the rest of the [EX-XDRiVER team](https://xdrv.team). Thank you!

## License

trackmaker is licensed under the [zlib License](https://opensource.org/license/Zlib),
Copyright © 2024-2025 Jill "oatmealine" Monoids.

Dependencies are subject to other licenses. More information is
available in [LICENSE.txt](./LICENSE.txt) and [love-license.txt](./platform/universal/love-license.txt).