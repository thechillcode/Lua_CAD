--[[--================================================================================

	Lua CAD fuctions
	provides simple useful functions to create stl files
	built on usage of openscad
	
	updated version this one creates a scad file which then can be processed by open scad
	Creates a cad obj that can be used, and imported by other cad objects
	
	cad.<function> returns a new cad object
	<obj>:<function> always changes the current obj
--]]--================================================================================

--[[--------------------------------------------------------------------------------
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
--]]--------------------------------------------------------------------------------

--[[--------------------------------------------------------------------------------
	Settings table
--]]--------------------------------------------------------------------------------
--[=[
local openscad_settings = {
	executable = [["C:\Program Files\OpenSCAD\openscad.exe"]],
	scadfile = [[D:\Temp\lua_openscad_tmp.scad]],
	include= ""
}
return openscad_settings
--]=]

require "lib_geometry" -- includes lib_vector
require "lib_dxf"
local oscad_settings = require "lib_cad_settings"

--[[--------------------------------------------------------------------------------
	GLOBAL CAD TABLE
--]]--------------------------------------------------------------------------------
cad = {}

-- OpenSCAD settings
cad.openscad = {}
cad.openscad.executable = oscad_settings.executable
cad.openscad.scadfile = oscad_settings.scadfile
cad.openscad.include = oscad_settings.include

--[[--------------------------------------------------------------------------------
	LOCAL OBJ HELPER FUNCTIONS
--]]--------------------------------------------------------------------------------
local executable = cad.openscad.executable
local scadfile = cad.openscad.scadfile

local function intend_content(this, count)
	this.intend_num = this.intend_num + count
end

local function update_content(this, str)
	local s = string.rep("\t", this.intend_num)
	str = s..string.gsub(str, "\n(.)", function(c) return "\n"..s..c end)
	this.scad_content = this.scad_content..str
end

--[[--------------------------------------------------------------------------------
	GLOBAL CAD DIRECT FUNCTIONS, returning new obj
--]]--------------------------------------------------------------------------------

--[[--------------------------------------------------------------------------------
	2D Native Part Functions
	
	Only give x and y, z is obsolete since linear extrude moves the item back to zero z.
--]]--------------------------------------------------------------------------------

--[[----------------------------------------
	function rect(x,y, width,height [,radius])
	
	if radius is given then rounds the corners of the rect accordingly
	draw rectangle width given width and height to dxf_file
--]]----------------------------------------
local scad_rect =[[
// rect
translate([$X,$Y,0])
square([$WIDTH,$HEIGHT]);
]]
function cad.rect(x,y, width,height, r, rad_angle)
	local obj = cad.obj()
	local rad_angle = rad_angle or "radius"
	if r then
		-- make 45° angle edges
		if rad_angle == "angle" then
			local t_points = {{0,r},{r,0},
				{width-r,0}, {width, r},
				{width,height-r}, {width-r, height},
				{r, height}, {0, height-r},
				}
			polygon(x,y, t_points)
			return
		-- round edges
		else
			translate(x,y)
				hull()
					circle(r,r, r)
					circle(width-r,r, r)
					circle(width-r,height-r, r)
					circle(r,height-r, r)
				hull_end()
			translate_end()
			return
		end
	end
	local t = {X=x, Y=y, WIDTH=width, HEIGHT=height}
	local _scad_content = string.gsub(scad_rect, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end
cad.square = rect

--[[------------------------------------------
	function circle(x,y, radius)
	
	inserts a circle
--]]------------------------------------------
local scad_circle =[[
// circle
translate([$X,$Y,0])
circle(r = $RADIUS);
]]
function cad.circle(x,y, radius)
	local obj = cad.obj()
	local t = {X=x, Y=y, RADIUS=radius}
	local _scad_content = string.gsub(scad_circle, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function polygon_raw(x,y, t_points)
	
	draw a polygon from given points {{x,y},{x,y},...,{x,y}}
	note angles are the outer angles measured
--]]------------------------------------------
local scad_polygon =[[
translate([$X,$Y,0])
polygon(points=$COORDINATES);
]]
function cad.polygon_raw(x,y, t_points, t_paths)
	local obj = cad.obj()
	-- create coordinates string
	local coor = "["
	for i,v in ipairs(t_points) do
		coor = coor.."["..v[1]..","..v[2].."],"
	end
	coor = string.sub(coor,1,-2).."]"
	if t_paths then
		coor = coor..",["
		for i,v in ipairs(t_paths) do
			coor = coor.."["..table.concat(v, ",").."],"
		end
		coor = string.sub(coor,1,-2).."]"
	end
	local t = {X=x, Y=y, COORDINATES=coor}
	local _scad_content = string.gsub(scad_polygon, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function polygon(x,y, t_points)
	
	points have to be counter clockwise
	draw a polygon from given points {{x,y},{x,y},...,{x,y}}
	note angles are the outer angles measured
	special functions:
		radius: radius one edge (radius [, segments]), replaces current point with radius
		belly: draw a belly between current and next point (distance [, segments])
--]]------------------------------------------
local t_fname = {
	["radius"] = function(pre, cur, nex, t_param)
		return geometry.round_corner(pre[1],pre[2], cur[1],cur[2], nex[1],nex[2], t_param[1], t_param[2])
	end,
	["belly"] = function(pre, cur, nex, t_param)
		local tp = geometry.belly(cur[1],cur[2], nex[1],nex[2], t_param[1], t_param[2])
		table.insert(tp, 1, cur)
		return tp	
	end,
}
function cad.polygon(x,y, t_points)
	local segs = segs or segments
	local t_p = {}
	for i,v in ipairs(t_points) do
		-- previus
		local prev = 0
		local nex = 0
		if i==1 then
			prev = t_points[#t_points]
		else
			prev = t_points[i-1]
		end
		if i==#t_points then
			nex = t_points[1]
		else
			nex = t_points[i+1]
		end
		local f_name = t_points[i][3]
		if f_name and t_fname[f_name] then
			local p = t_fname[f_name](prev, v, nex, t_points[i][4])
			for i,v in ipairs(p) do
				table.insert(t_p, v)
			end
		else
			table.insert(t_p, {v[1],v[2]})
		end
	end
	return cad.polygon_raw(x,y, t_p)
end

--[[------------------------------------------
	function longhole(x,y, dx,dy, radius)
	
	inserts a long hole into the given dxf_file
--]]------------------------------------------
local scad_longhole =[[
translate([$X,$Y,0])
{
	hull()
	{
		circle($RADIUS);
		translate([$DX,$DY,0])
		circle($RADIUS);
	}
}
]]
function cad.longhole(x,y, dx,dy, radius)
	local obj = cad.obj()
	local t = {X=x, Y=y, DX=dx, DY=dy, RADIUS=radius}
	local _scad_content = string.gsub(scad_longhole, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function longhole_points(x1, y1, x2, y2, radius)
	
	inserts a long hole into the given dxf_file
--]]------------------------------------------
local scad_longhole_p =[[
hull()
{
	translate([$X1,$Y1,0])
	circle($RADIUS);
	translate([$X2,$Y2,0])
	circle($RADIUS);
}
]]
function cad.longhole_points(x1,y1, x2, y2, radius)
	local obj = cad.obj()
	local t = {X1=x1, Y1=y1, X2=x2, Y2=y2, RADIUS=radius}
	local _scad_content = string.gsub(scad_longhole_p, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[----------------------------------------------------------------------------
	3D Native Part Functions
--]]----------------------------------------------------------------------------

--[[------------------------------------------
	function sphere(x, y, z, radius)
	
	draw a sphere
--]]------------------------------------------
local scad_sphere =[[
translate([$X,$Y,$Z])
sphere(r = $RADIUS);
]]
function cad.sphere(x, y, z, radius)
	local obj = cad.obj()
	local t = {X=x, Y=y, Z=z, RADIUS=radius}
	local _scad_content = string.gsub(scad_sphere, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function cube(x, y, z, width, height, depth)
	
	draw a cube
--]]------------------------------------------
local scad_cube =[[
translate([$X,$Y,$Z])
cube([$WIDTH,$HEIGHT,$DEPTH]);
]]
function cad.cube(x, y, z, width, height, depth)
	local obj = cad.obj()
	local t = {X=x, Y=y, Z=z, WIDTH=width, HEIGHT=height, DEPTH=depth}
	local _scad_content = string.gsub(scad_cube, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function cylinder(x, y, z, h, r1, r2)
	function cylinder(x, y, z, h, r1)
	
	draw a cylinder
--]]------------------------------------------
local scad_cylinder =[[
translate([$X,$Y,$Z])
cylinder($H,$R1,$R2);
]]
function cad.cylinder(x, y, z, h, r1, r2)
	local obj = cad.obj()
	local r2 = r2 or r1
	local t = {X=x, Y=y, Z=z, H=h, R1=r1, R2=r2}
	local _scad_content = string.gsub(scad_cylinder, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------
	function polyhedron(x,y,z, t_points)
	
	draw a polygon from given points {{x,y,z},{x,y,z},...,{x,y,z}}
	note angles are the outer angles measured
--]]------------------------------------------
local scad_polyhedron =[[
translate([$X,$Y,$Z])
polyhedron($COORDINATES, faces=$FACES);
]]
function cad.polyhedron(x,y,z, t_points, t_faces)
	local obj = cad.obj()
	-- create coordinates string
	local coor = "["
	for i,v in ipairs(t_points) do
		coor = coor.."["..v[1]..","..v[2]..","..v[3].."],"
	end
	coor = string.sub(coor,1,-2).."]"
	local faces = "["
	for i,v in ipairs(t_faces) do
		faces = faces.."["..table.concat(v, ",").."],"
	end
	faces = string.sub(faces,1,-2).."]"
	local t = {X=x, Y=y, Z=z, COORDINATES=coor, FACES=faces}
	local _scad_content = string.gsub(scad_polyhedron, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

--[[------------------------------------------------------------------------------------

	WRITE TEXT FUNCTION
	
	size = Height
	font = "Arial", "Courier New", "Liberation Sans", etc., default "Arial"
	style = depending on the font, usually "Bold","Italic", etc. default normal
	h_aling = horizontal alignment, Possible values are "left", "center" and "right". Default is "left".
	v_valign = vertical alignment for the text. Possible values are "top", "center", "baseline" and "bottom". Default is "baseline".

--]]------------------------------------------------------------------------------------

local scad_text =[[
translate([$X,$Y,$Z])
text("$TEXT", size=$H, font="$FONT", halign="$HALIGN", valign="$VALIGN");
]]
function cad.text(x,y,z, text, height, font, style, h_align, v_align)
	local obj = cad.obj()
	local height = height or 10
	local font = font or "Arial"
	local style = style and (":"..style) or ""
	local h_align = h_align or "center"
	local v_align = v_align or "center"
	local t = {X=x, Y=y, Z=z, TEXT=text, H=height, FONT=font..style, HALIGN=h_align, VALIGN=v_align}
	local _scad_content = string.gsub(scad_text, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

local scad_text_3D =[[
translate([$X,$Y,$Z])
linear_extrude(height = $DEPTH)
text("$TEXT", size=$H, font="$FONT", halign="$HALIGN", valign="$VALIGN");
]]
function cad.text_3D(x,y,z, text, height, depth, font, style, h_align, v_align)
	local obj = cad.obj()
	local height = height or 10
	local depth = depth or 5
	local font = font or "Arial"
	local style = style and (":"..style) or ""
	local h_align = h_align or "left"
	local v_align = v_align or "baseline"
	local t = {X=x, Y=y, Z=z, TEXT=text, H=height, DEPTH=depth, FONT=font..style, HALIGN=h_align, VALIGN=v_align}
	local _scad_content = string.gsub(scad_text_3D, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj
end

local scad_text_resize =[[
translate([$X,$Y,$Z])
resize([$W,$H,$D])
text("$TEXT", size=$H, font="$FONT", halign="$HALIGN", valign="$VALIGN");
]]
function cad.text_size(x,y,z, w,h,d, text, height, font, style, h_align, v_align)
	local obj = cad.obj()
	local size = size or 10
	local font = font or "Arial"
	local style = style and (":"..style) or ""
	local h_align = h_align or "center"
	local v_align = v_align or "center"
	local t = {X=x, Y=y, Z=z, W=w, H=h, D=d, TEXT=text, H=size, FONT=font..style, HALIGN=h_align, VALIGN=v_align}
	local _scad_content = string.gsub(scad_text, "%$(%w+)", t)
	update_content(obj, _scad_content)
	return obj	
end

--[[--------------------------------------------------------------------------------
	GEOMETRIC OBJECTS
--]]--------------------------------------------------------------------------------

--[[----------------------------------------
	pyramid
--]]----------------------------------------

function cad.pyramid(x,y,z, length, height)
	local t_points = {
		{0,0,0},{length,0,0},{length,length,0},{0,length,0},
		{length/2,length/2,height}
	}
	local t_faces = {
		{0,1,4},{1,2,4},{2,3,4},{3,0,4},{3,2,1,0}
	}
	local obj = cad.polyhedron(x,y,z, t_points, t_faces)
	return obj
end

--[[--------------------------------------------------------------------------------
	CAD OBJECT FUNCTIONS
--]]--------------------------------------------------------------------------------

local cad_meta = {}

cad.obj = function()
	local obj = setmetatable({}, cad_meta)
	obj:init()
	return obj
end
setmetatable(cad, {__call = cad.obj })

--[[--------------------------------------------------------------------------------
	GLOBAL OBJ FUNCTIONS via METATABLE
--]]--------------------------------------------------------------------------------
cad_meta.__index = {}

cad_meta.__index.init = function(obj)
	obj.scad_content = ""
	obj.segments = 12
	obj.intend_num = 0
	return obj
end
cad_meta.__index.reset = cad_meta.__index.init

cad_meta.__index.copy = function(obj)
	local copy = cad.obj()
	for i,v in pairs(obj) do
		copy[i] = v
	end
	return copy
end
cad_meta.__index.clone = cad_meta.__index.copy

-- 	optional $fn and $fs can be set (http://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Other_Language_Features#Special_variables)
cad_meta.__index.set_circle_fragments = function(obj, fn)
	obj.segments = fn
	return obj
end

--[[----------------------------------------
	Export to dxf, stl or obj with color color = {r,g,b}
--]]----------------------------------------
cad_meta.__index.export = function(obj, file, color, verbose)
	if verbose then
		print("---------------------------------")
		print("cad.export: -> "..file)
		print()
		print(cad.openscad.include)
		print("$fn = "..obj.segments..";")
		print(obj.scad_content)
		print()
		print("scad_file: "..scadfile)
		print("---------------------------------")
	end
	local obj_file = ""
	if string.lower(string.sub(file, -1, -5)) == ".obj" then
		obj_file = file
		file = scadfile..".stl"
		color = color or {255,255,255}
	end
	local fscad = io.open(scadfile, "w")
	if not fscad then
		error("Failed to write to scad file: "..fscad)
	end
	fscad:write(cad.openscad.include.."\n")
	fscad:write("$fn = "..obj.segments..";\n\n")
	fscad:write(obj.scad_content)
	fscad:close()
	os.execute(executable.." -o "..file.." "..scadfile)
	if obj_file ~= "" then
		cad.io.stl_to_obj(obj_file, {file}, {color})
	end
	return obj
end

--[[-----------------------------------
	GLOBAL CAD NATIVE FUNCTIONS
--]]-----------------------------------

-- for modules
function cad_meta.__index.use(obj, file)
	update_content(obj, "use <"..file..">;\n")
	return obj
end

-- for executing native code
function cad_meta.__index.native(obj, str)
	update_content(obj, "\n//native\n"..str.."\n")
	return obj
end

-- for importing stl
function cad_meta.__index.import(obj, file)
	update_content(obj, "import("..string.format("%q",file)..");\n")
	return obj
end

--[[-----------------------------------
	GLOBAL CAD FUNCTIONS (Dual)
--]]-----------------------------------

function cad_meta.__index.union(obj_1)
	local obj = cad.obj()
	update_content(obj, "union()\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

function cad_meta.__index.diff(obj_1, obj_2)
	local obj = cad.obj()
	update_content(obj, "difference()\n{\n")
	intend_content(obj, 1)
	update_content(obj, cad_meta.__index.union(obj_1).scad_content)
	update_content(obj, cad_meta.__index.union(obj_2).scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

function cad_meta.__index.add(obj_1, obj_2)
	local obj = cad.obj()
	update_content(obj, obj_1.scad_content)
	update_content(obj, obj_2.scad_content)
	obj_1.scad_content = obj.scad_content
	return obj_1
end

function cad_meta.__index.intersec(obj_1, obj_2)
	local obj = cad.obj()
	update_content(obj, "intersection()\n{\n")
	intend_content(obj, 1)
	update_content(obj, cad_meta.__index.union(obj_1).scad_content)
	update_content(obj, cad_meta.__index.union(obj_2).scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[----------------------------------------
	cad_meta.__index.scale(obj_1, x,y,z)
	
	scale an object in percent/100, 1=same size, 2=double, 0.5=half
--]]----------------------------------------
function cad_meta.__index.scale(obj_1, x,y,z)
	local obj = cad.obj()
	update_content(obj, "scale(["..x..","..y..","..z.."])\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function translate(x, y [, z])
	function translate_end()
	
	z is by default 0.
	move the objects in dxf_file relative by x and y
--]]------------------------------------------
function cad_meta.__index.translate(obj_1, x, y, z)
	local z = z or 0
	local obj = cad.obj()
	update_content(obj, "translate(["..x..","..y..","..z.."])\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function mirror(bx, by)
	function mirror_end()
	
	mirror the objects in dxf_file relative by x and y
--]]------------------------------------------
function cad_meta.__index.mirror(obj_1, x, y, z)
	local obj = cad.obj()
	update_content(obj, "mirror(["..x..","..y..","..z.."])\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function rotate(x, y, z, x_angle, y_angle, z_angle)
	function rotate_end()
	
	x and y are the rotation point
	rotate the objects in dxf_file relative by x and y
--]]------------------------------------------
function cad_meta.__index.rotate(obj_1, x, y, z, x_angle, y_angle, z_angle)
	local obj = cad.obj()
	update_content(obj, "translate(["..(x)..","..(y)..","..(z).."])\nrotate(["..x_angle..","..y_angle..","..z_angle.."])\ntranslate(["..(-x)..","..(-y)..","..(-z).."])\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function rotate2d(x,y, angle)
	function rotate2d_end()
	
	x and y are the rotation point
	rotate the objects in dxf_file relative by x and y
--]]------------------------------------------
function cad_meta.__index.rotate2d(obj_1, x,y, angle)
	local obj = cad.obj()
	update_content(obj, "translate(["..(x)..","..(y)..",0])\nrotate([0,0,"..angle.."])\ntranslate(["..(-x)..","..(-y)..",0])\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function rotate_extrude()
	function rotate_extrude_end()
	
	the object has to moved away from the center for rotate_extrude to succeed
--]]------------------------------------------
function cad_meta.__index.rotateextrude(obj_1)
	local obj = cad.obj()
	update_content(obj, "rotate_extrude()\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function hull()
	function hull_end()
	
	x and y are the rotation point
	rotate the objects in dxf_file relative by x and y
--]]------------------------------------------
function cad_meta.__index.hull(obj_1)
	local obj = cad.obj()
	update_content(obj, "hull()\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

--[[------------------------------------------
	function linear_extrude(num)
	
	note linear extrude moves the object back to the ground
--]]------------------------------------------
function cad_meta.__index.linearextrude(obj_1, num, twist, slices, scale)
	local twist = twist or 0 -- in degrees
	local slices = slices or 1 -- in how many slices it should be put
	local scale = scale or 1.0 -- if the object should be scaled towards extrusion
	local obj = cad.obj()
	update_content(obj, "linear_extrude(height = "..num..", twist = "..twist..", slices = "..slices..", scale = "..scale..", center = false)\n{\n")
	intend_content(obj, 1)
	update_content(obj, obj_1.scad_content)
	intend_content(obj, -1)
	update_content(obj, "}\n")
	obj_1.scad_content = obj.scad_content
	return obj_1
end

cad_meta.__add = function (a,b)
	return a:add(b)
end

cad_meta.__sub = function (a,b)
	return a:diff(b)
end

--[[----------------------------------------------------------------------------
	CAD object creating functions
--]]----------------------------------------------------------------------------


--[[--------------------------------------------------------------------------------
	FILE IO SUPPORT
--]]--------------------------------------------------------------------------------

cad.io = {}

--[[
	Convert ASCII STL file to OBJ (wavefront file) with optional coloring
	V 1.0
	Date: 2014-09-25
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
	
	Info:
	Imports an ASCII stl file into a t_faces structure
	t_faces is a table holding faces = {face 1,face 2,...,face n}
	each face consists of a normal and three points arranged in counter clock looking at of from the surface
		e.g. face = {normal,v1,v2,v3}
		where normal and v... are a table holding three floating point numbers e.g. {num1,num2,num3}
	Exports a t_faces structure into an OBJ file with optional coloring
	
	v2: multiple stl file support
--]]

-- add aditonal presets of colors here
local color_rgb = {
	["white"] = {1.0,1.0,1.0},
	["black"] = {0,0,0},
	["red"] = {1.0,0,0},
	["green"] = {0,1.0,0},
	["blue"] = {0,0,1.0},
	["cyan"] = {0,1.0,1.0},
	["magenta"] = {1.0,0,1.0},
	["yellow"] = {1.0,1.0,0},
}

--/////////////////////////////////////////////////////////////////
-- import ASCII STL file
-- stl files consist of a normal and three points aranged in counter clock
-- returns all the faces {{normal,v1,v2,v3},...}
-- where normal and v... are a table holding three floating point numbers e.g. {num1,num2,num3}
-- does not perform any checking on the file itself
local function cad_import_stl(filename)
	local file_stl,err = io.open(filename, "r")
	if err then error(err) end
	local t_faces = {}
	local cur_face = {}
	local count = 0
	for line in file_stl:lines() do
		if string.find(line, "^%s*facet normal") then
			local x,y,z = string.match(line, "(%S+)%s(%S+)%s(%S+)$")
			table.insert(cur_face, {tonumber(x),tonumber(y),tonumber(z)})
		end
		if string.find(line, "^%s*vertex") then
			local x,y,z = string.match(line, "(%S+)%s(%S+)%s(%S+)$")
			table.insert(cur_face, {tonumber(x),tonumber(y),tonumber(z)})
			count = count + 1
			if count == 3 then
				table.insert(t_faces,cur_face)
				cur_face = {}
				count = 0
			end
		end
	end
	file_stl:close()
	return t_faces
end


--/////////////////////////////////////////////////////////////////
-- export t_faces structure to OBJ (wavefront) file
-- filename: full filepath to obj file
-- t_faces a t_faces structure
-- color is optional and has to be a table holding three r,g,b, numbers e.g. {[0,255],[0,255],[0,255]} or a string e.g. "white"
cad.io.stl_to_obj = function(obj_filename, t_stl_filenames, t_colors)

	-- strip only filename
	local filename = string.match(obj_filename,"([^\\/]+)%.%S%S%S$")

	-- if color then write mtl
	local mtl_filename = filename..".mtl"
	local file,err = io.open(mtl_filename, "w")
	if err then error(err) end
	local t_mtl_color = {}
	for i,v in ipairs(t_colors) do
		--print(v)
		local col = {}
		if color_rgb[v] then
			color = color_rgb[v]
		else
			color = {v[1]/255,v[2]/255,v[3]/255}
		end
		local mtl_color = "color_["..string.format("%.06f-%.06f-%.06f",color[1], color[2], color[3]).."]_"..i
		file:write(
			"# Color: "..mtl_color.."\n"..
			"newmtl "..mtl_color.."\n"..
			"Ka "..string.format("%.06f %.06f %.06f",color[1], color[2], color[3]).."\n"..
			"Kd "..string.format("%.06f %.06f %.06f",color[1], color[2], color[3]).."\n"..
			"Ks 0.000000 0.000000 0.000000\n"..
			"Ns 2.000000\n"..
			"d 1.000000\n"..
			"Tr 1.000000\n\n")
		table.insert(t_mtl_color, mtl_color)
	end
	file:close()

	-- get all vertices
	local t_faces = {}
	for i,v in ipairs(t_stl_filenames) do
		table.insert(t_faces, cad_import_stl(v))
	end
	
	-- write obj
	
	local file,err = io.open(obj_filename, "w")
	if err then error(err) end

	file:write("#########################################\n")
	file:write("# Wavefront .obj file\n")
	file:write("# Created by: lib_cad.lua\n")
	file:write("# Date: "..os.date().."\n")
	file:write("#########################################\n\n")

	if color then
		file:write("#########################################\n")
		file:write("# MTL lib:\n\n")
		file:write("mtllib "..mtl_filename.."\n\n")
	end

	-- List of Vertices
	file:write("#########################################\n")
	file:write("# List of vertices:\n\n")

	for _,t_v in ipairs(t_faces) do
		for i,v in ipairs(t_v) do
			for i2=2,4 do
				file:write("v "..string.format("%f",v[i2][1]).." "..string.format("%f",v[i2][2]).." "..string.format("%f",v[i2][3]).."\n")
			end
		end
	end
	file:write("\n")

	-- Normals in (x,y,z) form; normals might not be unit.
	-- Normals are not needed since stl saves the triangles in counter clock anyways
	--file:write("\n# List of Normals\n\n")
	--for i,v in ipairs(t_faces) do
	--	file:write("vn "..string.format("%f",v[1][1]).." "..string.format("%f",v[1][2]).." "..string.format("%f",v[1][3]).."\n")
	--end

	-- Face Definitions (see below)
	local count = 0
	for i,v in ipairs(t_mtl_color) do
	
		file:write("\n#########################################\n")
		file:write("# Face definitions:\n\n")

		if color then
			file:write("usemtl "..v.."\n\n")
		end

		for i,v in ipairs(t_faces[i]) do
			local i2 = (count)*3
			--file:write("f "..(i2+1).."//"..i.." "..(i2+2).."//"..i.." "..(i2+3).."//"..i.."\n")
			file:write("f "..(i2+1).." "..(i2+2).." "..(i2+3).."\n")
			count = count + 1
		end
	end
	file:close()
end

--[[--------------------------------------------------------------------------------
	STL DIRECT SUPPORT
--]]--------------------------------------------------------------------------------

cad.stl = {}

function cad.stl.write(filename, s_stl)
	local f,err = io.open(filename, "w")
	if err then error(err) end
	f:write(s_stl)
	f:close()
end

function cad.stl.cube(x,y,z, width,height,depth)

	local w,h,d = width,height,depth
	
	local vertex = {
		{	{-1, 0, 0},
			{0, 0, d},
			{0, h, d},
			{0, 0, 0}
		},
		{	{-1, 0, 0},
			{0, 0, 0},
			{0, h, d},
			{0, h, 0}
		},
		{	{0, 0, 1},
			{0, 0, d},
			{w, 0, d},
			{w, h, d},
		},
		{	{0, 0, 1},
			{0,h,d},
			{0,0,d},
			{w,h,d},
		},
		{	{0,-1,0},
			{0,0,0},
			{w,0,0},
			{w,0,d},
		},
		{	{0,-1,0},
			{0,0,d},
			{0,0,0},
			{w,0,d},
		},
		{	{0,0,-1},
			{0,h,0},
			{w,h,0},
			{0,0,0},
		},
		{	{0,0,-1},
			{0,0,0},
			{w,h,0},
			{w,0,0},
		},
		{	{0,1,0},
			{0,h,d},
			{w,h,d},
			{0,h,0},
		},
		{	{0,1,0},
			{0,h,0},
			{w,h,d},
			{w,h,0},
		},
		{	{1,0,0},
			{w,0,0},
			{w,h,0},
			{w,h,d},
		},
		{	{1,0,0},
			{w,0,d},
			{w,0,0},
			{w,h,d},
		}
	}
	
	-- create stl string
	local indent = "  "
	local stl = "solid cube\n"
	for i,v in ipairs(vertex) do
		stl = stl..indent.."facet normal "..v[1][1].." "..v[1][2].." "..v[1][3].."\n"
		stl = stl..indent..indent.."outer loop\n"
		stl = stl..indent..indent..indent.."vertex "..(x+v[2][1]).." "..(y+v[2][2]).." "..(z+v[2][3]).."\n"
		stl = stl..indent..indent..indent.."vertex "..(x+v[3][1]).." "..(y+v[3][2]).." "..(z+v[3][3]).."\n"
		stl = stl..indent..indent..indent.."vertex "..(x+v[4][1]).." "..(y+v[4][2]).." "..(z+v[4][3]).."\n"
		stl = stl..indent..indent.."endloop\n"
	end
	stl = stl.."ensolid cube\n"
	
	return stl
end
