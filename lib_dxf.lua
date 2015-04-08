
--[[-----------------------------------
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
	
	Info:
	http://www.autodesk.com/techpubs/autocad/acad2000/dxf/entities_section.htm
	http://www.autodesk.com/techpubs/autocad/acad2000/dxf/common_group_codes_for_entities_dxf_06.htm#XREF_22164_DXF_06
--]]-----------------------------------

require "lib_vector"

-- simple function to modify a dxf file

-- main dxf function table
local dxf_index = {}

--[[------------------------------------------
	function dxf([dxf_file])
	
	Imports a dxf object, but only reads LINE & CIRCLE, does not copy layers
	returns a dxf object
--]]------------------------------------------
local os_header = [[  0
SECTION
  2
BLOCKS
  0
ENDSEC
  0
SECTION
  2
ENTITIES
]]
local os_footer = [[  0
ENDSEC
  0
SECTION
  2
OBJECTS
  0
DICTIONARY
  0
ENDSEC
  0
EOF
]]
local import_values = {
	["LINE"] = {
		[10] = 0,
		[11] = 0,
		[20] = 0,
		[21] = 0,
	},
	
	["CIRCLE"] = {
		[10] = 0,
		[20] = 0,
		[40] = 0,
	},
}
local import_listeners =
{
	["LINE"] = function(dxf_obj, cmd, value)
		local t = import_values["LINE"]
		if cmd == 0 then
			dxf_obj:line(t[10], t[20], t[11], t[21], "0")
		end
		if t[cmd] then t[cmd] = value end
	end,
	
	["CIRCLE"] = function(dxf_obj, cmd, value)
		local t = import_values["CIRCLE"]
		if cmd == 0 then
			dxf_obj:circle(t[10], t[20], t[40], "0")
		end
		if t[cmd] then t[cmd] = value end
	end,
}
local function dxf_read_cmd_value(file)
	local line = file:read("*l")
	if not line then return end
	local cmd = string.find(line, "%s-(%d+)")
	local line = file:read("*l")
	if not line then return end
	return tonumber(cmd),line
end
function dxf(dxf_file)
	local dxf_obj = {}
	setmetatable(dxf_obj, {__index = dxf_index})
	
	if dxf_file then
		local f,err = io.open(dxf_file,"r")
		if err then print(err) return end
		
		local cur_func = nil
		
		local cmd,value = dxf_read_cmd_value(f)
		while cmd do
			if cur_func then curfunc(dxf_obj, cmd, value) end
			if cmd == 0 then -- check for function
				cur_func = import_listeners[value]
			end
			cmd,value = dxf_read_cmd_value(f)
		end
		
		f:close()
	end
	return dxf_obj
end

--[[------------------------------------------
	function <dxf>:addlayer(name)
	
	colorindex := 0=black, 1=red, ... (http://sub-atomic.com/~moses/acadcolors.html) according to AutoCAD Color Index (ACI)
	style := CONTINUOUS
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.addlayer = function(obj, name, colorindex, style)
	if (name == 0) then error("Layer name cannot be: "..name) end
	obj.layers = obj.layers or {}
	table.insert(obj.layers, {NAME=name, COLORINDEX = (colorindex or "0"), STYLE=(style or "CONTINUOUS")})
	return obj
end

--[[------------------------------------------
	function <dxf>:text(text, x, y, height, angle, font, layer)
	
	font := STANDARD
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.text = function(obj, text, x, y, height, angle, font, thickness, layer)
	obj.texts = obj.texts or {}
	table.insert(obj.texts, {TEXT=text, THICKNESS=(thickness or "0"), X=x, Y=y, HEIGHT=height, ANGLE=(angle or "0"), FONT=(font or "STANDARD"), LAYER=(layer or "0")})
	return obj
end

--[[------------------------------------------
	function <dxf>:mtext(text, x, y, height, angle, font, layer)
	
	font := STANDARD
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.mtext = function(obj, text, x, y, height, angle, font, width, layer)
	obj.mtexts = obj.mtexts or {}
	table.insert(obj.mtexts, {TEXT=text, WIDTH=(width or "100"), X=x, Y=y, HEIGHT=height, ANGLE=(angle or "0"), FONT=(font or "STANDARD"), LAYER=(layer or "0")})
	return obj
end

--[[------------------------------------------
	function <dxf>:line(x1, y1, x2, y2, layer)
	
	font := STANDARD
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.line = function(obj, x1, y1, x2, y2, layer)
	obj.lines = obj.lines or {}
	table.insert(obj.lines, {X1=x1, Y1=y1, X2=x2, Y2=y2, LAYER=(layer or "0")})
	return obj
end

--[[------------------------------------------
	function <dxf>:rect(x1, y1, w, h, layer)
	
	font := STANDARD
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.rect = function(obj, x1, y1, w, h, layer)
	obj:line(x1,y1, x1+w,y1, layer)
	obj:line(x1+w,y1, x1+w,y1+h, layer)
	obj:line(x1,y1+h, x1+w,y1+h, layer)
	obj:line(x1,y1, x1,y1+h, layer)
	return obj
end

--[[------------------------------------------
	function <dxf>:circle(x, y, radius, layer)
	
	returns dxf object or raises an error
--]]------------------------------------------
dxf_index.circle = function(obj, x, y, radius, layer)
	obj.circles = obj.circles or {}
	table.insert(obj.circles, {X=x, Y=y, RADIUS=radius, LAYER=(layer or "0")})
	return obj
end

dxf_index.cross = function(obj, x,y, length, layer)
	local l_2 = length/2
	obj:line(x-l_2, y, x+l_2, y, layer)
	obj:line(x, y-l_2, x, y+l_2, layer)
	return obj
end

dxf_index.circle_cross = function(obj, x,y, radius, length, layer)
	obj:circle(x,y, radius, layer)
	obj:cross(x,y, length, layer)
	return obj
end

--[[------------------------------------------
	function <dxf>:curved_arrow_cc(x, y, radius, len, layer)
	
	x,y, center coordinated
	radius, radius of the curved arrow
	len, length of the arrow lines
--]]------------------------------------------
dxf_index.curved_arrow_cc = function(obj, x, y, radius, s, layer)
	local v = vector(radius, 0)
	local segs = 120
	local sep_deg = 40
	local _s = math.rad(180+sep_deg)
	local _e = math.rad(180-sep_deg)
	local _seg = ((2*math.pi)-(_s-_e))/segs
	local p = v:rot(_s)
	for i=1,segs do
		local n = v:rot(_s+(i*_seg))
		obj:line(x+p[1], y+p[2], x+n[1], y+n[2], layer)
		p = n
	end
	-- draw arrow, arrow angle
	local alpha = math.rad(40)
	local op = p:op():unit() * s
	local tip = vector(x,y)+p
	local v1 = op:rot((math.pi/2)-alpha)
	local v2 = op:rot((math.pi/2)+alpha)
	v1 = tip+v1
	v2 = tip+v2
	obj:line(tip[1], tip[2], v1[1], v1[2], layer)
	obj:line(tip[1], tip[2], v2[1], v2[2], layer)
end

--[[------------------------------------------
	function <dxf>:save(dxf_file)
	
	returns dxf object or raises an error
--]]------------------------------------------
local layer_start = [[0
SECTION
2
TABLES
0
TABLE
2
LAYER
70
6
]]
local layer_add = [[0
LAYER
2
$NAME
70
64
62
$COLORINDEX
6
$STYLE
]]
local layer_end = [[0
ENDTAB
0
ENDSEC
]]
local text_add = [[  0
TEXT
  8
$LAYER
 39
$THICKNESS
 10
$X
 20
$Y
 11
$X
 21
$Y
 40
$HEIGHT
 50
$ANGLE
 1
$TEXT
 7
$FONT
 72
1
]]
local mtext_add = [[  0
MTEXT
  8
$LAYER
 10
$X
 20
$Y
 11
$X
 21
$Y
 40
$HEIGHT
 41
$WIDTH
 50
$ANGLE
 1
$TEXT
 7
$FONT
 71
5
 72
4
]]
local line_add = [[  0
LINE
  8
$LAYER
 10
$X1
 11
$X2
 20
$Y1
 21
$Y2
]]
local circle_add = [[  0
CIRCLE
  8
$LAYER
 10
$X
 20
$Y
 30
0
 40
$RADIUS
]]
dxf_index.save = function(obj, dxf_file)
	local f,err = io.open(dxf_file,"w")
	if err then print(err) return end
	if obj.layers then
		f:write(layer_start)
		for i,v in ipairs(obj.layers) do
			local slayer = string.gsub(layer_add, "%$(%w+)", v)
			f:write(slayer)
		end
		f:write(layer_end)
	end
	-- write vector
	f:write(os_header)
	--f:write(obj.svector)
	if (obj.lines) then
		for i,v in ipairs(obj.lines) do
			local sline = string.gsub(line_add, "%$(%w+)", v)
			f:write(sline)
		end	
	end
	if (obj.circles) then
		for i,v in ipairs(obj.circles) do
			local stext = string.gsub(circle_add, "%$(%w+)", v)
			f:write(stext)
		end	
	end
	if (obj.texts) then
		for i,v in ipairs(obj.texts) do
			local stext = string.gsub(text_add, "%$(%w+)", v)
			f:write(stext)
		end	
	end
	if (obj.mtexts) then
		for i,v in ipairs(obj.mtexts) do
			local stext = string.gsub(mtext_add, "%$(%w+)", v)
			f:write(stext)
		end	
	end
	f:write(os_footer)
	f:close()
	return obj
end

-- make dxf global to be loaded using require
return dxf