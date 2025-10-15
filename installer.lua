-- Installer for Milos ComputerCraft Projects
local token = arg[1]

local repo = "miluum-one/computercraft-projects"
local branch = "main"
local apiUrl = "https://api.github.com/repos/" .. repo .. "/git/trees/" .. branch .. "?recursive=1"
local rawUrlPrefix = "https://raw.githubusercontent.com/" .. repo .. "/" .. branch .. "/"
local whitelistDirs = { "apps", "lib", "src" } -- e.g., {"dir1", "dir2/subdir"}; set to nil or {} to download all files
local installedFiles = {}
local createdDirectories = {}

local function createHeaders(isApiRequest)
  local headers = {}
  if token then
    headers["Authorization"] = "token " .. token
  end
  if isApiRequest then
    headers["Accept"] = "application/vnd.github.v3+json"
  end
  return headers
end

local function httpGet(url, isApiRequest)
  local headers = createHeaders(isApiRequest)
  local ok, err = http.checkURL(url)
  if not ok then
    error("Invalid URL or HTTP disabled: " .. err)
  end
  local request = http.get(url, headers)
  if not request then
    error("Failed to make HTTP request to " .. url)
  end
  local response = request.readAll()
  local status = request.getResponseCode and request.getResponseCode() or 200
  request.close()
  if status ~= 200 then
    error("HTTP request failed with status " .. status .. " for " .. url)
  end
  return response
end

local function ensureDirectory(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  local current = ""
  for i = 1, #parts - 1 do
    current = current .. (i == 1 and "" or "/") .. parts[i]
    if not fs.exists(current) then
      fs.makeDir(current)
      table.insert(createdDirectories, current)
    end
  end
end

local function downloadFile(path)
  local url = rawUrlPrefix .. path
  print("Downloading: " .. path)
  local content = httpGet(url, false)
  ensureDirectory(path)
  local file = fs.open(path, "w")
  if file then
    file.write(content)
    file.close()
    print("Saved: " .. path)
    table.insert(installedFiles, path)
  else
    error("Failed to save file: " .. path)
  end
end

local function isWhitelisted(path, whitelist)
  if not whitelist or #whitelist == 0 then
    return true
  end
  for _, dir in ipairs(whitelist) do
    if path:sub(1, #dir + 1) == dir .. "/" then
      return true
    end
  end
  return false
end

local function downloadTree()
  local response = httpGet(apiUrl, true)
  local data = textutils.unserializeJSON(response)
  if not data or not data.tree then
    error("Failed to parse tree data or no tree found")
  end

  for _, item in ipairs(data.tree) do
    if item.type == "blob" and isWhitelisted(item.path, whitelistDirs) then
      downloadFile(item.path)
    end
  end
end

local function saveCreatedFilePaths()
  if #installedFiles == 0 then return end
  local toSave = textutils.serialise(installedFiles)
  local file = fs.open("/appdata/installer/files.txt", "w")
  file.write(toSave)
  file.close()
end

local function saveCreatedDirectories()
  if #createdDirectories == 0 then return end
  local toSave = textutils.serialise(createdDirectories)
  local file = fs.open("/appdata/installer/dirs.txt", "w")
  file.write(toSave)
  file.close()
end

local success, err = pcall(downloadTree)
if not success then
  print("Error: " .. err)
else
  saveCreatedFilePaths()
  saveCreatedDirectories()
  print("Download complete. You may now remove this file.")
end
