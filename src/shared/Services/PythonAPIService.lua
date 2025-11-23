-- ReplicatedStorage/Shared/Services/PythonAPIService.lua

local HttpService = game:GetService("HttpService")
local PythonAPIService = {}

-- ## 설정: 파이썬 서버의 주소를 입력하세요 ##
-- Roblox 스튜디오에서 테스트할 때는 127.0.0.1 대신 실제 로컬 IP 주소(예: 192.168.0.5)를 사용해야 합니다.
local BASE_URL = "http://harohalo.duckdns.org:20082"
-- local BASE_URL = "http://localhost:20082"

--- 쿼리 파라미터 테이블을 URL 문자열로 변환합니다.
local function buildQueryString(paramsTable)
    if not paramsTable or next(paramsTable) == nil then return "" end
    
    local parts = {}
    for key, value in pairs(paramsTable) do
        table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
    end
    
    return "?" .. table.concat(parts, "&")
end

--[[
API endpoint에 GET 요청을 보내고, 응답받은 JSON을 Lua 테이블로 자동 해독합니다.

@param endpoint (string): 요청할 엔드포인트 (예: "/params", "/test")
@param queryParams (table): URL에 추가할 쿼리 파라미터
@return (boolean, table | string): 성공 여부, 성공 시 해독된 Lua 테이블, 실패 시 에러 메시지
--]]
function PythonAPIService.get(endpoint, queryParams)
    local url = BASE_URL .. endpoint .. buildQueryString(queryParams)
    
    -- pcall now wraps both the network request AND the JSON decoding step.
    -- This ensures that any error (network or parsing) is caught safely.
    local success, result = pcall(function()
        print("PythonAPIService: 요청 URL - " .. url)
        -- Step 1: Get the raw JSON string from the server.
        local jsonString = HttpService:GetAsync(url)
        
        -- Step 2: Decode the JSON string directly into a Lua table.
        local dataTable = HttpService:JSONDecode(jsonString)
        
        return dataTable
    end)
    
    if success then
        -- On success, 'result' is the decoded Lua table.
        return true, result
    else
        -- On failure, 'result' is the error message from either GetAsync or JSONDecode.
        return false, "API Request/Decode Error: " .. tostring(result)
    end
end

return PythonAPIService
