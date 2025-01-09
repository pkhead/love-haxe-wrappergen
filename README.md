This project uses the awesome [love-api][] project, which provides a lua tables representation of the love documention, to generate Haxe wrappers.
To use this project, make sure to checkout the submodule (`git submodule update --init love-api`).

Fair warning, the code is awful, and full of hacks. Look, it was easy.

[love-api]: https://github.com/love2d-community/love-api

## Changes from upstream:
- LOVE modules are more convenient to use:
    - They are located directly under the `love` package.
    - Their names are no longer suffixed with "Module".
- love.Application class, which allows classes that extend it to set LOVE callbacks by overriding functions from the base class.

## Examples:
```haxe
class TextDrawing extends love.Application {
    override function draw() {
        love.Graphics.print("Hello, world!", 400, 300);
    }

    public static function main() {
        new TextDrawing();
    }
}
```

```haxe
class ImageDrawing extends love.Application {
    var whale:love.graphics.Texture;

    override function load(args:Array<String>, unfilteredArgs:Array<String>) {
        whale = love.Graphics.newImage("whale.png");
    }

    override function draw() {
        love.Graphics.draw(whale, 300, 200);
    }

    public static function main() {
        new ImageDrawing();
    }
}
```

```haxe
class SoundPlaying extends love.Application {
    override function load(args:Array<String>, unfilteredArgs:Array<String>) {
        var sound = love.Audio.newSource("music.ogg", Stream);
        love.Audio.play(sound); // or sound.play();
    }

    public static function main() {
        new SoundPlaying();
    }
}
```