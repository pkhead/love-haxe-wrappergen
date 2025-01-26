class TextDrawing extends love.Application {
    override function draw() {
        love.Graphics.print("Hello, world!", 400, 300);
    }

    public static function main() {
        new TextDrawing();
    }
}