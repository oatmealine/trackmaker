# trackmaker

Heavily work-in-progress GUI chart editor for [EX-XDRiVER](https://store.steampowered.com/app/2636020/EXXDRiVER/).

## Run

Download a [release](https://github.com/oatmealine/trackmaker/releases).
Currently, there are none, but when the editor is in a more workable state
they'll become available.

## Develop

1. Get [nfd](https://github.com/Vexatos/nativefiledialog/tree/master/lua) w/ [luarocks](https://luarocks.org):
  
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