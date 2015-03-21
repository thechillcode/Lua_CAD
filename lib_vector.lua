-----------------
-- vector library
-----------------
--[[------------------------------------------
	a vector consists of function triangle_pionts_from_sides(side_a, side_b, side_c)

	vector is 2D will add 3D support
--]]------------------------------------------

--[[-----------------------------------
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
--]]-----------------------------------


local vec_meta = {}

function vector(x, y, z)
	local v = {x,y}
	return setmetatable(v, vec_meta)
end
vec = vector


-- functions
function vec_meta.__add(a, b)
	return vector(a[1]+b[1], a[2]+b[2])
end

function vec_meta.__sub(a, b)
	return vector(a[1]-b[1], a[2]-b[2])
end

function vec_meta.__mul(a, b)
	if type(a) == "table" then
		local var = b
		b=a
		a=var
	end
	return vector(a*b[1], a*b[2])
end

function vec_meta.__len(a)
	return math.sqrt((a[1]*a[1]) + (a[2]*a[2]))
end

function vec_meta.__tostring(a)
	return "x: "..a[1]..", y: "..a[2]
end

-- __index functions
vec_meta.__index = {}
local idx = vec_meta.__index
 
function idx.unit(vec)
	return vec*(1/#vec)
end
 
function idx.normal(vec, op)
	local op = op or 1
	return vector((-op)*vec[2], (op)*vec[1])
end
 
function idx.scalar(vec1, vec2)
	return (vec1[1]*vec2[1] + vec1[2]*vec2[2])
end

function idx.op(vec1)
	return vector(-vec1[1],-vec1[2])
end

function idx.rot(vec, phi)
	local x = math.cos(phi)*vec[1] - math.sin(phi)*vec[2]
	local y = math.sin(phi)*vec[1] + math.cos(phi)*vec[2]
	return vector(x,y)
end

function idx.angle(vec1, vec2)
	local scalar = vec1:scalar(vec2)
	local cos_alpha = scalar/ (#vec1*#vec2)
	return math.acos(cos_alpha)
end