
--[[-----------------------------------
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
--]]-----------------------------------

require "lib_vector"

--[[--------------------------------------------------------------------------------
	GEOMETRY TABLE
--]]--------------------------------------------------------------------------------
geometry = {}

--[[------------------------------------------
	triangle_pionts_from_sides(side_a, side_b, side_c)
	
	calc triangle when 3 sides are given

	http://en.wikipedia.org/wiki/Triangle#Sine.2C_cosine_and_tangent_rules
	alpha = arccos((b²+c²-a²)/2bc)

	c = bottom side, a(right), b(left)
	
	returns A,B,C, alpha,beta,gamma
--]]------------------------------------------
geometry.get_triangle_from_sides = function(side_a, side_b, side_c)

	local alpha = math.acos((((side_b*side_b)+(side_c*side_c)-(side_a*side_a))/(2*side_b*side_c)));
	
	-- calc point C
	y = math.round(math.sin(alpha)*side_b)
	x = math.round(math.cos(alpha)*side_b)
	
	return {0,0},{side_c,0},{x,y}, math.deg(alpha)
end


-- function to draw pyramid
geometry.get_pyramid_circumcenter = function(length, height)
	-- calc circumcenter point
	-- calc side len half
	local len_2 = length/2
	local l = math.sqrt((len_2*len_2)+(height*height))
	--local l_2 = l/2
	-- calc angle
	--local alpha = math.asin(height/l)
	local d = (l*l)/(2*height)
	-- return hight above ground
	return height-d
end

geometry.get_pyramid_innercircumcenter = function(length, height)
	-- calc innercircumcenter point
	local beta = math.atan((2*height)/length)
	local alpha = beta/2
	local d = (math.tan(alpha)*length)/2
	return d
end


-- x1,y1 and x2,y2 are the vector, width is the hight from the middle of the vector to radius
geometry.get_radius_from_circle_segment = function(x1, y1, x2, y2, width)
	local s_vec = {x1-x2, y1-y2}
	local s_vec_len = math.sqrt((s_vec[1]*s_vec[1]) + (s_vec[2]*s_vec[2]))
	-- calc radius
	local radius = ((4*(width*width)) + (s_vec_len*s_vec_len)) / (8*width)
	
	-- s_vec with len 1
	local s_vec_one = { (s_vec[2])/s_vec_len, s_vec[1]/s_vec_len }
	-- s_vec with normal
	local s_vec_norm = {s_vec_one[1], -s_vec_one[2]}

	-- calc radius point
	local rp = {x2+(s_vec[1]/2), y2+(s_vec[2]/2)}
	local vlen = radius - width
	local rp = {rp[1]+(s_vec_norm[1]*vlen), rp[2]+(s_vec_norm[2]*vlen)}
	
	return rp, radius
end

-- returns points following a belly function
geometry.belly = function(x1, y1, x2, y2, dist, circle_seg)
	local circle_seg = circle_seg or 120
	local angle_seg = 360/circle_seg
	local rp, radius = geometry.get_radius_from_circle_segment(x1, y1, x2, y2, dist)
		
	local v1 = vector(x1-rp[1], y1-rp[2])
	local v2 = vector(x2-rp[1], y2-rp[2])

	-- get angle between
	--print("Angle: "..math.deg(v1:angle(v2)))
	local angle = math.deg(v1:angle(v2))
	
	
	local num = math.floor(angle/angle_seg)
	--print("Segments: "..num)
	local rest = (angle - (num*angle_seg))/2
	
	local t_points = {}
	
	local vrot = v1:rot(math.rad(rest))
	table.insert(t_points, {vrot[1]+rp[1], vrot[2]+rp[2]})
	for i=1,num do
		vrot = vrot:rot(math.rad(angle_seg))
		table.insert(t_points, {vrot[1]+rp[1], vrot[2]+rp[2]})
	end
	
	return t_points
end

-- get rounding center of three points (two vectors with one center points)
-- points have to be in counter clock direction
geometry.get_round_center = function(x1,y1, x2,y2, x3,y3, radius, outside)
	local outside = outside or false
	-- calc vecs
	local vec_1 = vector(x1-x2, y1-y2)
	local vec_2 = vector(x3-x2, y3-y2)
	
	local gamma = math.acos(vec_1:scalar(vec_2)/(#vec_1*#vec_2))
	-- get oposite
	gamma = math.pi - gamma
	local gamma_2 = gamma/2
	local alpha = gamma_2
	
	-- triangle A,B,C, a,b,c
	local c = math.abs(radius)
	local a = math.tan(alpha)*c
	
	local vec_a = vec_1:unit()*a
	local op = -1
	if outside == true then
		op = 1
	end
	local vec_c = vec_1:unit():normal(op)*c
	--print(vec_1, vec_2, vec_a, vec_c)
	
	-- get radius point
	local A = vector(x2,y2)+vec_a+vec_c
	local B = vector(x2,y2)+vec_a
	local D = vector(x2,y2)+(vec_2:unit()*a)
	return A,B,D,gamma
end

--[[------------------------------------------
	function round_corner(x1,y1, x2,y2, x3,y3, radius, segments)
	
	returns points to use instead of the middle point e.g. {x,y},{x,y}
--]]------------------------------------------
geometry.round_corner = function(x1,y1, x2,y2, x3,y3, radius, segments)
	local segments = segments or 120
	local seg_rad = (2*math.pi)/segments
	
	local outside = false
	if radius < 0 then outside = true end
	local A,B,D,gamma = geometry.get_round_center(x1,y1, x2,y2, x3,y3, radius, outside)
	
	local vec_ab = B-A
	local vec_ad = D-A
	
	local segs = math.floor(gamma/seg_rad)
	if segs == 0 then
		--local p = A + vec_ab:rot(gamma/2)
		return {B,D}
	end
	
	local rest = (gamma - (seg_rad*segs))/2
	if rest < 1 then rest = 0 end
	
	local rot = 0
	-- calc new points
	local t_points = {B}
	if rest > 0 then
		if radius < 0 then
			rot = rot - rest
		else
			rot = rot + rest
		end
		local p = A + vec_ab:rot(rot)
		table.insert(t_points, p)
	end
	for i=1,segs do
		if radius < 0 then
			rot = rot - seg_rad
		else
			rot = rot + seg_rad
		end
		local p = A + vec_ab:rot(rot)
		table.insert(t_points, p)
	end
	table.insert(t_points, D)
	return t_points
end

-- Geometric Objects

-- returns the coordinates of a tetrahedron with equal sides
geometry.tetrahedron = function(side)
	local A = {0,0,0}
	local B = {side,0,0}
	-- calc C
	local h = side*math.sqrt(0.5)
	local C = {side/2,h,0}
	-- middle point, center point gravity point
	local M = {side/2, h/3}
	local h_D = side*math.sqrt(1/3)
	local D = {side/2, h/3, h_D}
	
	return A,B,C,D
end