local logger = {}
function logger:info(msg)  print("[INFO]  " .. msg) end
function logger:warn(msg)  print("[WARN]  " .. msg) end
function logger:error(msg) error("[ERROR] " .. msg, 2) end
return logger
