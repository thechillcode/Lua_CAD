--// create stl or dxf file

require "lib_cad"
require "lib_geometry"
require "lib_dir"

local path = dir.get_working_dir()

-- output file
local cad_file = path.."\\template_design.stl"

-- create cad object





cad.export(cad_file)

-- dxf add info
--[[
local f = dxf.import(cad_file)

f:addlayer("INFO")
f:text(name, (w/2)/2, h/2, 8, 0, _, _, "INFO")

f:save(cad_file)
--]]