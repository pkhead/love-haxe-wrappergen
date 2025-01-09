-- Be warned, here be dragons

api = require "love-api.love_api"

do
	-- Map types to their modules, so we can properly do imports
	local lovetypes = {}

	for _, type in ipairs(api.types) do
		lovetypes[type.name] = "love"
	end

	for _, module in ipairs(api.modules) do
		local modulename = "love." .. module.name
		if module.types then
			for _, type in ipairs(module.types) do
				lovetypes[type.name] = modulename
			end
		end
		if module.enums then
			for _, type in ipairs(module.enums) do
				lovetypes[type.name] = modulename
			end
		end
	end

	-- types: { name -> true }
	function resolveImports(types, package)
		local imports = {}
		for i, v in pairs(types) do
			local module = lovetypes[i]
			if module and module ~= package then
				table.insert(imports, ("import %s.%s;"):format(module, i))
			end
		end
		table.sort(imports)
		return table.concat(imports, "\n")
	end
end

do
	-- The keys are type names, the values are their "priority",
	-- the most generic base class (Object) has the lowest priority.
	-- Used to find the most specific supertype later on.
	local priority = {}
	priority["Object"] = 0

	-- Now we first need a complete registry of types and their supertypes
	local supertypes = {}
	for _, type in ipairs(api.types) do
		supertypes[type.name] = type.supertypes or {}
	end

	for _, module in ipairs(api.modules) do
		if module.types then
			for _, type in ipairs(module.types) do
				supertypes[type.name] = type.supertypes or {}
			end
		end
		if module.enums then
			for _, type in ipairs(module.enums) do
				supertypes[type.name] = type.supertypes or {}
			end
		end
	end

	-- To assign the priority of a type, take the maximum priority of its
	-- supertypes and add 1.
	local function assignPriority(name)
		if priority[name] then
			-- Priority is known, skip
			return priority[name]
		end

		local max = -math.huge
		for i, v in ipairs(supertypes[name]) do
			max = math.max(max, assignPriority(v))
		end

		priority[name] = max+1
		return max+1
	end

	-- Now assign all priorities, and dump the type list
	for i, v in pairs(supertypes) do
		assignPriority(i)
	end
	supertypes = nil

	-- Now we can just return the supertype with the highest priority
	function mostSpecificSupertype(t)
		local maxVal, maxPriority = "UserData", -math.huge
		for i, v in ipairs(t) do
			local priority = priority[v]
			if priority > maxPriority then
				maxVal, maxPriority = v, priority
			end
		end
		return maxVal
	end
end

do
	local map =
	{
		number = "Float",
		string = "String",
		boolean = "Bool",
		table = "Table<Dynamic,Dynamic>",
		["light userdata"] = "UserData",
		userdata = "UserData",
		["function"] = "Dynamic", -- FIXME
		mixed = "Dynamic",
		value = "Dynamic",
		any = "Dynamic",
		Variant = "Dynamic",
		cdata = "Dynamic",

		-- FIXME
		["ShaderVariableType"] = "String",
	}
	
	function typeMap(t)
		-- FIXME: union types
		if string.find(t, " or ") then
			return "Dynamic"
		else
			return map[t] or t
		end
	end
end

function funcArguments(arguments, types, isFuncType)
	if arguments == nil or arguments[1] == nil then
		if isFuncType then
			return "(Void)"
		end

		return "()"
	end

	local concat = {}

	table.insert(concat, "(")
	for i, arg in ipairs(arguments) do
		if i > 1 then
			table.insert(concat, ",")
		end

		if isFuncType then
			table.insert(concat, arg.name)
			table.insert(concat, ":")
		end

		table.insert(concat, haxeType(arg, types))
	end
	table.insert(concat, ")")

	return table.concat(concat)
end

function haxeType(typeTable, types)
	if typeTable.type == "function" then
		local concat = {funcArguments(typeTable.arguments, types, true)}

		table.insert(concat, "->")

		-- TODO: multiple returns?
		if typeTable.returns ~= nil then
			table.insert(concat, haxeType(typeTable.returns[1], types))
		else
			table.insert(concat, "Void")
		end

		return table.concat(concat)
	else
		local t = typeMap(typeTable.type)
		
		if types then
			types[t] = true
		end

		return t
	end
end

function capitalize(s)
	return s:sub(1, 1):upper() .. s:sub(2)
end

function isValueInTable(t, q)
	for _, v in pairs(t) do
		if v == q then
			return true
		end
	end

	return false
end

do
	-- if an identifier begins with a digit,
	-- prepend an underscore
	local numbers = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}
	function correctIdentifier(s)
		local firstCh = string.sub(s, 1, 1)

		for _, v in ipairs(numbers) do
			if v == firstCh then
				return "_" .. s
			end
		end

		return s
	end
end

-- fix backslashes and doublequotes
function escapeString(s)
	return s:gsub("\\", "\\\\"):gsub("\"", "\\\"")
end

function mergeTables(target, src, prefix)
	prefix = prefix or ""
	for i, v in pairs(src) do
		target[prefix .. i] = v
	end
	return target
end

function dirname(path)
	return path:match("^(.-)/?[^/]+$")
end

function emitMultiReturnType(name, returns, types)
	local parts = {}
	parts[1] = ("\n@:multiReturn\nextern class %s\n{\n"):format(name)
	for i, v in ipairs(returns) do
		-- TODO: Maybe never? Vararg return can't really be modeled.
		if v.name ~= "..." then
			local type = haxeType(v, types)
			table.insert(parts, ("\tvar %s : %s;\n"):format(v.name, type))
		end
	end
	table.insert(parts, "}")

	return table.concat(parts)
end

function emitOverload(typeName, name, o, types, multirets)
	local args = {}
	for i, v in ipairs(o.arguments or {}) do
		v.type = haxeType(v, types)
		v.name = v.name:match("^\"(.*)\"$") or v.name -- FIXME: workaround for love.event.quit

		if v.name == "..." then
			table.insert(args, ("args:Rest<%s>"):format(v.type))
		else
			local arg = (v.default and "?" or "") .. v.name .. ":" .. v.type
			table.insert(args, arg)
		end
	end
	local retType = "Void"
	if o.returns and #o.returns > 1 then
		-- In case of multiple returns we need to generate a new return type
		retType = typeName .. capitalize(name) .. "Result"
		multirets[name] = emitMultiReturnType(retType, o.returns, types)
	elseif o.returns then
		retType = haxeType(o.returns[1], types)
	end
	return ("(%s) : %s"):format(table.concat(args, ", "), retType)
end

function callbackSignature(c, types)
	local type = {funcArguments(c.arguments, types, false)}
	table.insert(type, "->")

	if c.returns then -- TODO: Multiple returns?
		if c.returns[1].type == "function" then
			table.insert(type, "(")
			table.insert(type, haxeType(c.returns[1], types))	
			table.insert(type, ")")
		else
			table.insert(type, haxeType(c.returns[1], types))
		end
	else
		table.insert(type, "Void")
	end

	return table.concat(type)
end

function emitCallback(c, types)
	-- TODO: Multiple variants? Does that even exist?
	return ("\tpublic static var %s : %s;"):format(c.name, callbackSignature(c.variants[1], types))
end

function rawEmitFunction(typeName, f, types, static, multirets)
	if private == nil then
		private = false
	end

	local out = {""}

	local sigs = {}
	for i, v in ipairs(f.variants) do
		table.insert(sigs, emitOverload(typeName, f.name, v, types, multirets))
	end

	local main = table.remove(sigs, 1)
	for i, v in ipairs(sigs) do
		table.insert(out, ("\t@:overload(function %s {})"):format(v))
	end

	table.insert(out, ("\tpublic%s function %s%s;"):format(static and " static" or "", f.name, main))
	return table.concat(out, "\n")
end

function emitCallbackFunctionHeader(typeName, f, types, static, multirets)
	if private == nil then
		private = false
	end

	local out = {""}

	local sigs = {}
	table.insert(sigs, emitOverload(typeName, f.name, f.variants[1], types, multirets))

	local main = table.remove(sigs, 1)
	for i, v in ipairs(sigs) do
		table.insert(out, ("\t@:overload(function %s {})"):format(v))
	end

	table.insert(out, ("\tprivate%s function %s%s"):format(static and " static" or "", f.name, main))
	return table.concat(out, "\n")
end

function emitFunction(typeName, f, types, multirets)
	return rawEmitFunction(typeName, f, types, true, multirets)
end

function emitMethod(typeName, m, types, multirets)
	return rawEmitFunction(typeName, m, types, false, multirets)
end

function emitEnum(e, packageName)
	local overrideFile = io.open(("overrides/%s.%s.hx"):format(packageName, e.name), "r")
	if overrideFile then
		local contents = overrideFile:read("*a")
		overrideFile:close()
		return {[e.name .. ".hx"] = contents}
	end

	local out = {}
	table.insert(out, ("package %s;"):format(packageName))
	table.insert(out, ("enum abstract %s (String)\n{"):format(e.name))

	for i, v in ipairs(e.constants) do
		table.insert(out, ("\tvar %s = \"%s\";"):format(correctIdentifier(capitalize(v.name)), escapeString(v.name)))
	end

	table.insert(out, "}")
	return {[e.name .. ".hx"] = table.concat(out, "\n")}
end

function emitHeader(out, packageName)
	table.insert(out, ("package %s;"):format(packageName))
	table.insert(out, "import haxe.extern.Rest;")
	table.insert(out, "import lua.Table;")
	table.insert(out, "import lua.UserData;")
	table.insert(out, "")
end

function emitType(t, packageName)
	local overrideFile = io.open(("overrides/%s.%s.hx"):format(packageName, t.name), "r")
	if overrideFile then
		local contents = overrideFile:read("*a")
		overrideFile:close()
		return {[t.name .. ".hx"] = contents}
	end

	local out = {}
	local types = {}
	local multirets = {}
	emitHeader(out, packageName)

	local superType = t.supertypes and mostSpecificSupertype(t.supertypes) or "UserData"
	table.insert(out, ("extern class %s extends %s\n{"):format(t.name, superType))

	for i, v in ipairs(t.functions or {}) do
		table.insert(out, emitMethod(t.name, v, types, multirets))
	end

	table.insert(out, "}")
	table.insert(out, 2, resolveImports(types, packageName))

	for i, v in pairs(multirets) do
		table.insert(out, v)
	end
	return {[t.name .. ".hx"] = table.concat(out, "\n")}
end

function emitModule(m, luaName)
	local out = {}
	local files = {}
	local types = {}
	local multirets = {}

	local moduleName = luaName or "love." .. m.name
	local prefix = moduleName:gsub("%.", "/") .. "/"
	emitHeader(out, "love")
	table.insert(out, ("@:native(\"%s\")"):format(moduleName))
	local className = capitalize(luaName or m.name)
	table.insert(out, ("extern class %s"):format(className))
	table.insert(out, "{")

	for i, v in ipairs(m.functions) do
		table.insert(out, emitFunction(className, v, types, multirets))
	end

	for i, v in ipairs(m.callbacks or {}) do
		table.insert(out, emitCallback(v, types))
	end

	table.insert(out, "}")

	for i, v in ipairs(m.enums or {}) do
		mergeTables(files, emitEnum(v, moduleName), prefix)
	end

	for i, v in ipairs(m.types or {}) do
		mergeTables(files, emitType(v, moduleName), prefix)
	end

	table.insert(out, 2, resolveImports(types, moduleName))
	table.insert(out, 2, ("import %s.*;"):format(moduleName))

	for i, v in pairs(multirets) do
		table.insert(out, v)
	end
	files["love/" .. className .. ".hx"] = table.concat(out, "\n")
	return files
end

function getCallbackData(cbName)
	local cbData = nil
	for _, v in pairs(api.callbacks) do
		if v.name == cbName then
			cbData = v
			break
		end
	end
	return cbData
end

function emitAppClass()
	local out = {}
	local files = {}
	local types = {}
	local multirets = {}
	local cbNames = {}

	local moduleName = "love.Application"
	emitHeader(out, "love")

	local callbacksWithDefaults = {"run", "errorhandler", "quit"}

	table.insert(out, "class Application {")
	table.insert(out, "\tstatic var instance:Application = null;")

	for _, cbName in pairs(callbacksWithDefaults) do
		local cbType = callbackSignature(getCallbackData(cbName).variants[1], types)
		table.insert(out, ("\tvar default_%s:%s = Love.%s;"):format(cbName, cbType, cbName))
	end

	for _, cb in pairs(api.callbacks) do
		if cb.name ~= "conf" and cb.name ~= "load" then
			table.insert(cbNames, cb.name)

			if not isValueInTable(callbacksWithDefaults, cb.name) then
				table.insert(out, emitCallbackFunctionHeader("Application", cb, types, false, multirets))
				table.insert(out, "\t{}")
			end
		end
	end

	table.insert(out, "\tprivate function load(args:Array<String>) {}");
	
	for _, cbName in pairs(callbacksWithDefaults) do
		--local cbType = callbackSignature(api.callbacks[cbName], types)
		local cbData = getCallbackData(cbName)
		print(cbName)
		local argConcat = {}

		if cbData.variants[1].arguments then
			for i, arg in ipairs(cbData.variants[1].arguments) do
				if i > 1 then
					table.insert(argConcat, ", ")
				end
				table.insert(argConcat, arg.name)
			end
		end

		table.insert(out, emitCallbackFunctionHeader("Application", cbData, types, false, multirets))
		table.insert(out, ("\t{ return default_%s(%s); }"):format(cbName, table.concat(argConcat)))
	end

	table.insert(out, [[
	
	public function new() {
		if (instance != null) throw new haxe.Exception("Cannot create more than one instance of love.Application.");
		instance = this;
		
		Love.load = (argsTable:lua.Table<Dynamic, Dynamic>, unfilteredArgs:lua.Table<Dynamic, Dynamic>) -> {
			var args:Array<String> = [];
			var i = 1;
			while (argsTable[i] != null) {
				args.push(argsTable[i]);
				i++;
			}
			
			load(args);
		}
]])

	for _, cbName in pairs(callbacksWithDefaults) do
		table.insert(out, ("\t\tLove.%s = %s;"):format(cbName, cbName))
	end
	
	for _, name in pairs(cbNames) do
		table.insert(out, ("\t\tLove.%s = %s;"):format(name, name))
	end

	table.insert(out, "\t}\n}")
	
	table.insert(out, 2, resolveImports(types, moduleName))

	for i, v in pairs(multirets) do
		table.insert(out, v)
	end

	files["love/Application.hx"] = table.concat(out, "\n")
	return files
end

local files = {}

for i, v in ipairs(api.modules) do
	mergeTables(files, emitModule(v))
end

mergeTables(files, emitModule(api, "love"))
mergeTables(files, emitAppClass())

local dirSep = package.config:sub(1, 1)
for i, v in pairs(files) do
	if dirSep == "/" then -- unix
		os.execute("mkdir -p " .. dirname(i))
	else -- windows
		os.execute("mkdir " .. dirname(i):gsub("/", dirSep))
	end

	local f = io.open(i, "w")
	f:write(v)
	f:close()
end
