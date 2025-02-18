import love.graphics.GraphicsModule;
import love.keyboard.KeyboardModule;
import love.keyboard.KeyConstant;
import haxe.Exception;

class KeyConstantTest extends love.Application {
    var keyConstants:Array<String>;
    var scancodes:Array<String>;

    static function main() {
        new KeyConstantTest();
    }

    public function new() {
        super();
        keyConstants = Macros.getValues(KeyConstant);
        scancodes = Macros.getValues(love.keyboard.Scancode);

        for (v in keyConstants) {
            try {
                if (KeyboardModule.isScancodeDown(cast v)) {
                    trace('$v is down');
                }
            } catch (e:Exception) {
                trace(e);
            }
        }

        for (v in scancodes) {
            try {
                if (KeyboardModule.isScancodeDown(cast v)) {
                    trace('$v is down');
                }
            } catch (e:Exception) {
                trace(e);
            }
        }
    }

    override function draw() {
        var y = 0.0;

        for (v in keyConstants) {
            if (KeyboardModule.isDown(cast v)) {
                GraphicsModule.print(v, 0, y);
                y += 10;
            }
        }

        // y = 0.0;

        // for (v in scancodes) {
        //     if (love.Keyboard.isDown(cast v)) {
        //         love.Graphics.print(v, love.Graphics.getWidth() / 2, y);
        //         y += 10;
        //     }
        // }
    }
}