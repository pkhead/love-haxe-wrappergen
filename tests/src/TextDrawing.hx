import love.graphics.GraphicsModule as LoveGraphics;

class TextDrawing extends love.Application {
    override function draw() {
        LoveGraphics.print("Hello, world!", 400, 300);
    }

    public static function main() {
        new TextDrawing();
    }
}