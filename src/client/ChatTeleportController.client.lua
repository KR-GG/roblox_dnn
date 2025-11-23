-- StarterPlayerScripts/ChatTeleportController.lua

--// 서비스 및 플레이어 객체 불러오기 //--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [수정] MapService를 추가로 불러옵니다.
local TeleportService = require(ReplicatedStorage.Shared.Services.TeleportService)
local MapService = require(ReplicatedStorage.Shared.Services.MapService)

local player = Players.LocalPlayer
local TELEPORT_PREFIX = "!tp "

--// 서버의 맵 로드가 완료될 때까지 기다립니다. (안정성 확보) //--
local currentMapValue = ReplicatedStorage:WaitForChild("CurrentMapValue")
if not currentMapValue.Value then
	print("ChatTeleportController: 서버의 맵 로드를 기다립니다...")
	currentMapValue.Changed:Wait()
end
print("ChatTeleportController: 서버 맵 준비 완료, 텔레포트 기능 활성화.")


-- 플레이어의 채팅 이벤트를 감지
player.Chatted:Connect(function(message)
	local lowerMessage = string.lower(message)

	if string.sub(lowerMessage, 1, #TELEPORT_PREFIX) == TELEPORT_PREFIX then
		local keyword = string.sub(lowerMessage, #TELEPORT_PREFIX + 1)

		--- 🔽 [핵심 로직 변경] 🔽 ---

		-- 1. TeleportService에 키워드에 해당하는 '모델 이름'을 문의합니다.
		local targetModelName = TeleportService.getTargetModelName(keyword)

		if not targetModelName then
			print("'" .. keyword .. "'에 해당하는 텔레포트 위치를 찾을 수 없습니다.")
			return
		end

		-- 2. MapService를 통해 현재 로드된 맵을 가져옵니다.
		local currentMap = MapService.getCurrentMap()
		if not currentMap then
			warn("텔레포트 실패: 현재 로드된 맵을 찾을 수 없습니다.")
			return
		end

		-- 3. 현재 맵 안에서 해당 이름의 모델을 찾습니다.
		local targetModel = currentMap:FindFirstChild(targetModelName)

		if not targetModel then
			warn(string.format("텔레포트 실패: '%s' 맵 안에 '%s' 모델이 없습니다.", currentMap.Name, targetModelName))
			return
		end

		-- 4. 모델의 PrimaryPart와 그 위치를 확인합니다.
		if not targetModel.PrimaryPart then
			warn(string.format("텔레포트 실패: '%s' 모델에 PrimaryPart가 설정되어 있지 않습니다.", targetModelName))
			return
		end

		local targetPosition = targetModel.PrimaryPart.Position

		-- 5. 위치가 유효하다면, 플레이어 캐릭터를 해당 위치로 텔레포트합니다.
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			print(string.format("'%s'(으)로 텔레포트합니다...", targetModelName))
			local rootPart = character.HumanoidRootPart
			-- 땅에 박히지 않도록 살짝 위로 텔레포트
			rootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 5, 0))
		end
	end
end)