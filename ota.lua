local function exec_template(fname)
  file.open(fname, "r")
  local txt = {}
  
  while true do
    ln = file.readline()
    if (ln == nil) then break end

    for w in string.gmatch(ln, "{{$[^}]+}}") do
      f = loadstring("return ".. string.sub(w,4,-3))
      local nw = string.gsub(w, "[^%a%s]", "%%%1")
      ln = string.gsub(ln, nw, f())
    end
    
    txt[#txt+1] = ln
  end
  file.close()
  return table.concat(txt, "")
end

local function load_file(fname, ftxt, fcheck, cmpl)
  file.remove("update/" .. fname)
  file.open("update/" .. fname, "w")
  file.write(ftxt)
  file.flush()
  file.close()
-- check written file to be complete
  file.open("update/" .. fname, "r")
  file.seek("end", -8)
  ln = string.sub(file.readline(), 0, 7)
  print(ln)
  if(ln == "--EOF--") then -- successfully EOF detected
    file.close()
    file.remove(fname)
    file.rename("update/" .. fname, fname) -- rename to file to be replaced
    if string.sub(fname, -3, -1) == "lua" and cmpl == true and fname ~= "init.lua" then
      if pcall(function() node.compile(fname) end ) then
        print("Update compiled")
        file.remove(fname)
      end
    end
    print("Update done")
    return "OK"
  else
    file.close()
    file.remove("update/" .. fname)
    print("Update failed")
    return "NOK"
  end 
end


local pl = nil;
local sv=net.createServer(net.TCP, 10) 

sv:listen(80,function(conn)
  
  conn:on("sent", function(conn) 
    print("sent")
  end)
  
  conn:on("disconnection", function(conn) 
    print("disco")
  end)
  conn:on("receive", function(conn, pl) 
    local payload = pl;
    if string.sub(pl, 0, 9) == "**LOAD**#"  then
      print("HTTP : File received...")
      pl = string.sub(pl,10,-1)
      local idxf = string.find(pl,"#")
      local fname = string.sub(pl, 0, idxf-1)
      print("Name: " ..  fname)
      local idx = string.find(pl,"#", idxf+1)
      local fcheck = string.sub(pl, idxf+1, idx)
      local ftxt = string.sub(pl, idx+1, -1)
      print("fcheck: " .. fcheck)
      print("ftxt: " .. string.len(ftxt))
      conn:send(load_file(fname, ftxt, fcheck, false))
    elseif string.sub(pl, 0, 12) == "**RESTART**" then
      print("HTTP : Restarting")
      node.restart()
    else
      print("HTTP : default page")
      conn:send("HTTP/1.x 200 OK\n" .. exec_template("page.tmpl"))
    end
    
    tmr.alarm(1, 1000, 0, function() 
        print("Heap1: " .. node.heap())
        conn:close()
        collectgarbage()
        print("Heap2: " .. node.heap())
    end )
  end)
end)
print("Server running...")
