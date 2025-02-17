import haxe.macro.ExprTools;
import haxe.macro.Expr;
import haxe.macro.Context;

class Macros {
    public static macro function getValues(typePath:Expr):Expr {
        // Get the type from a given expression converted to string.
        // This will work for identifiers and field access which is what we need,
        // it will also consider local imports. If expression is not a valid type path or type is not found,
        // compiler will give a error here.
        var type = Context.getType(ExprTools.toString(typePath));
        var entries:Array<Expr> = [];

        switch (type) {
            case TAbstract(t, params):
                var deref = t.get();
                for (field in deref.impl.get().statics.get()) {
                    switch (field.expr().expr) {
                        case TCast(e, m):
                            switch (e.expr) {
                                case TConst(c):
                                    switch (c) {
                                        case TString(s):
                                            entries.push(macro $v{s});

                                        default: Context.error("not an enum abstract", Context.currentPos());
                                    }
                                
                                default: Context.error("not an enum abstract", Context.currentPos());
                            }

                        default: Context.error("not an enum abstract", Context.currentPos());
                    }
                }

            default: Context.error("not an enum abstract", Context.currentPos());
        }

        return macro $a{entries};

        // // Switch on the type and check if it's an abstract with @:enum metadata
        // switch (type.follow()) {
        // case TDAbstract(_.get() => ab, _):
        //     // @:enum abstract values are actually static fields of the abstract implementation class,
        //     // marked with @:enum and @:impl metadata. We generate an array of expressions that access those fields.
        //     // Note that this is a bit of implementation detail, so it can change in future Haxe versions, but it's been
        //     // stable so far.
        //     var valueExprs = [];
        //     for (field in ab.impl.get().statics.get()) {
        //     if (field.meta.has(":enum") && field.meta.has(":impl")) {
        //         var fieldName = field.name;
        //         valueExprs.push(macro $typePath.$fieldName);
        //     }
        //     }
        //     // Return collected expressions as an array declaration.
        //     return macro $a{valueExprs};
        // default:
        //     // The given type is not an abstract, or doesn't have @:enum metadata, show a nice error message.
        //     throw new Error(type.toString() + " should be @:enum abstract", typePath.pos);
        // }
    }
}