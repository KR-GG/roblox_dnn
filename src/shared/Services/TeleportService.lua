-- ReplicatedStorage/Shared/Services/TeleportService.lua

local TeleportService = {}

-- 텔레포트 위치 데이터베이스
-- 키워드에 해당하는 '모델의 이름'을 저장합니다.
local targetModels = {
    -- string.lower()로 처리되므로 키워드는 모두 소문자로 작성합니다.
    ["perceptron"] = "Perceptron",
    ["network"] = "VisualNetwork",
    ["forward"] = "Forward",
}

--- 키워드를 받아서 해당하는 '모델의 이름'을 반환하는 함수
function TeleportService.getTargetModelName(keyword)
    -- 키워드가 targetModels 테이블에 있는지 확인하고, 있으면 모델 이름을 반환
    return targetModels[keyword]
end

return TeleportService