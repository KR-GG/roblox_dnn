-- ReplicatedStorage/Shared/Services/MapService.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapService = {}

local currentMapValue = ReplicatedStorage:WaitForChild("CurrentMapValue")

--- 다른 스크립트들이 현재 로드된 맵을 가져갈 때 사용하는 함수
function MapService.getCurrentMap()
    -- 이제 내부 변수가 아닌, 모두에게 복제된 ObjectValue의 값을 직접 읽습니다.
    local currentMap = currentMapValue.Value
    
    if not currentMap or not currentMap.Parent then
        warn("MapService: 현재 로드된 맵이 없습니다! 서버가 아직 준비 중일 수 있습니다.")
        return nil
    end
    return currentMap
end

return MapService
