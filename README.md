# LÖVE for Haxe
This is an updated fork of the original [love-haxe-wrappergen][] by bartbes. It uses the awesome [love-api][] project, which provides a Lua tables representation of the LÖVE documentation, to generate Haxe wrappers.

This project is currently only tested to work on LÖVE 11.5.

[love-api]: https://github.com/love2d-community/love-api
[love-haxe-wrappergen]: https://github.com/bartbes/love-haxe-wrappergen

## Table of contents
1. [Installation](#installation)
2. [Examples](#examples)
3. [Changes from upstream](#changes-from-upstream)
4. [Source maps with Local Lua Debugger](#source-maps-with-local-lua-debugger)

## Installation
### Installing prebuilt externs
```bash
haxelib install love
```

### Using `haxelib git`
This requires that you have the Lua standalone interpreter installed.

Run, in a terminal:
```bash
haxelib git love https://github.com/pkhead/love-haxe-wrappergen

# PowerShell: cd $env:HAXEPATH/lib/love/git
# Windows Command Prompt: cd %HAXEPATH%/lib/love/git
# Bash:
cd $HAXEPATH/lib/love/git

git submodule update --init love-api
lua haxify.lua
```

### Using `haxelib dev`
This requires that you have the Lua standalone interpreter installed.

Run, in a terminal:
```bash
git clone https://github.com/pkhead/love-haxe-wrappergen
cd love-haxe-wrappergen
git submodule update --init love-api
lua haxify.lua
haxelib dev love .
```

## Examples:
### build.hxml
```hxml
-lib love
-cp src
-D lua-vanilla
--lua out/main.lua

--main MyGame
```

### Code samples
```haxe
import love.graphics.GraphicsModule as LoveGraphics;

class TextDrawing extends love.Application {
    override function draw() {
        LoveGraphics.print("Hello, world!", 400, 300);
    }

    public static function main() {
        new TextDrawing();
    }
}
```

```haxe
import love.graphics.GraphicsModule as LoveGraphics;

class ImageDrawing extends love.Application {
    var whale:love.graphics.Texture;

    override function load(args:Array<String>, unfilteredArgs:Array<String>) {
        whale = LoveGraphics.newImage("whale.png");
    }

    override function draw() {
        LoveGraphics.draw(whale, 300, 200);
    }

    public static function main() {
        new ImageDrawing();
    }
}
```

```haxe
import love.audio.AudioModule as LoveAudio;

class SoundPlaying extends love.Application {
    override function load(args:Array<String>, unfilteredArgs:Array<String>) {
        var sound = LoveAudio.newSource("music.ogg", Stream);
        LoveAudio.play(sound); // or sound.play();
    }

    public static function main() {
        new SoundPlaying();
    }
}
```

## Changes from upstream:
- love.Application class, which allows classes that extend it to set LÖVE callbacks by overriding functions from the base class.
- `love.filesystem.FilesystemRead` class for type-safe file reading.
- Emitted documentation for functions and classes.

## Source Maps with Local Lua Debugger
**Note: As of 01/26/2025 the current stable version of Haxe (4.3.6) cannot generate Lua source maps. This section is for once that feature is released or if you are using a nightly/development version of Haxe.**

This section is for if want to use the Visual Studio Code extension Local Lua Debugger by Tom Blind to debug your Love2D project. This debugger has the option to use source maps following the JavaScript format. Setup is required in order for it to work properly.

### 1. Fix Local Lua Debugger
Because of [this issue (#84)](https://github.com/tomblind/local-lua-debugger-vscode/issues/84), the extension does not work properly with Haxe-generated source maps. If the bug has been fixed by the time you are reading this, you do not need to follow this step. Otherwise, there is a fork which fixes this issue, so I have detailed to steps required to get it working.

1. Uninstall the Marketplace extension. (obviously.)
2. Ensure you have git and npm installed.
3. Run in a terminal:
    ```bash
    git clone https://github.com/Zorbn/local-lua-debugger-vscode
	cd local-lua-debugger-vscode
	
    npm install
    npm run build
	npx vsce package
	
	code --install-extension <path to newly created .vsix file>
	# or, you can install the .vsix file through the vscode command palette
	# or from the right-click menu of the file inside vscode.
    ```

### 2. Create launch configuration
You need to add the following entry to the `.vscode/launch.json` file (assumes the `out` folder is where the Love2D project is generated):
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Love2D Debug",
            "type": "lua-local",
            "request": "launch",
            "program": {
                "command": "lovec"
            },
            "cwd": "${workspaceFolder}/out",
            "args": ["."],
            "scriptFiles": ["*.lua"],
        }
    ]
}
```

### 3. Hook into lldebugger on application startup
At the very top of your application's main function (chosen because it is the earliest point at which code can execute), add the following code:
```haxe
untyped __lua__("
if os.getenv('LOCAL_LUA_DEBUGGER_VSCODE') == '1' then
    require('lldebugger').start()

    function assert(a, b)
        return a or error(b or 'assertion failed!', 2)
    end

    function love.errorhandler(msg)
        error(msg, 3)
    end
end
");
```

Once all required steps have been followed, breakpoints set in your Haxe source code (hopefully) should work, and the Visual Studio Code call stack should (hopefully) display the correct Haxe functions rather than the Lua code.