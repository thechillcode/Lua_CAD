
--[[-----------------------------------
	Author: Michael Lutz
	Licensed under the same terms as Lua itself
--]]-----------------------------------

local path = [[D:\temp\]]

dir = {}

-- get working directory
function dir.get_working_dir()
	local fname = os.tmpname ()
	os.execute("CD > "..fname)
	local f = io.open(fname)
	local cd = f:read("*a")
	f:close()
	os.remove(fname)
	--return string.sub(cd,1,-2).."\\"
	return string.sub(cd,1,-2)
end

function dir.get_files(folder)
	local dir_file = path.."dir.txt"
	os.execute("DIR \""..folder.."\" /A:-D /B /O:N > "..dir_file)
	local file = io.open(dir_file)
	local tfiles = {}
	for line in file:lines() do
		table.insert(tfiles, line)
	end
	file:close()
	os.remove(dir_file)
	return tfiles
end

function dir.get_directories(folder)
	local dir_file = path.."dir.txt"
	os.execute("DIR \""..folder.."\" /A:D /B /O:N > "..dir_file)
	local file = io.open(dir_file)
	local tfiles = {}
	for line in file:lines() do
		table.insert(tfiles, line)
	end
	file:close()
	os.remove(dir_file)
	return tfiles
end

function dir.remove_dir(folder)
	os.execute("RD \""..folder.."\" /S /Q")
end

function dir.create_dir(folder)
	os.execute("MD \""..folder.."\" /S /Q")
end