-- StarterPlayerScripts/ChatAnimatorController.lua

--// 서비스 및 모듈 불러오기 //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--- [추가] MapService를 불러와 현재 맵의 경로를 알아냅니다.
local MapService = require(ReplicatedStorage.Shared.Services.MapService)

print("1. AnimateCommandHandler 스크립트 실행 시작.")

--// 모듈 불러오기 //--
local animatorModulePath = ReplicatedStorage:FindFirstChild("Forward") and ReplicatedStorage.Forward:FindFirstChild("NetworkAnimator")
if not animatorModulePath then
	error("오류: ReplicatedStorage/Forward/NetworkAnimator 경로에 모듈이 없습니다!")
	return
end
local PrebuiltAnimator = require(animatorModulePath)
print("2. 애니메이터 모듈을 성공적으로 불러왔습니다.")

--- [수정] 서버의 맵 로드가 완료될 때까지 기다리는 로직 ---
local currentMapValue = ReplicatedStorage:WaitForChild("CurrentMapValue")
if not currentMapValue.Value then
	print("ChatAnimatorController: 서버의 맵 로드를 기다립니다...")
	currentMapValue.Changed:Wait()
end
print("ChatAnimatorController: 서버 맵 준비 완료 신호 확인!")
------------------------------------------------------

--// 대상 모델 찾기 //--
--- [수정] Workspace에서 직접 찾는 대신, 현재 로드된 맵 안에서 찾습니다.
local currentMap = MapService.getCurrentMap()
if not currentMap then
	error("오류: MapService에서 현재 맵을 찾을 수 없습니다!")
	return
end
local modelToAnimate = currentMap:WaitForChild("Forward", 10) -- 10초 동안 기다림.

if not modelToAnimate then
	error(string.format("오류: '%s' 맵에서 'Forward' 모델을 10초 동안 찾았지만 없습니다!", currentMap.Name))
	return
end
print("3. '"..currentMap.Name.."' 맵에서 '"..modelToAnimate.Name.."' 모델을 찾았습니다.")


--// 채팅 명령어 설정 //--
local COMMAND = "/animate"
local isAnimating = false
local COOLDOWN = 10

--// 플레이어의 채팅을 감지하는 함수 //--
local function onPlayerChatted(player, message)
	local msgLower = message:lower()

	if isAnimating then
		print("애니메이션이 이미 진행 중입니다. 잠시 후 다시 시도해주세요.")
		return
	end

	if msgLower == COMMAND then
		print("'"..player.Name.."'님이 전체 사이클 애니메이션 실행을 요청했습니다.")
		isAnimating = true

		PrebuiltAnimator.playFullCycle(modelToAnimate)

		task.wait(COOLDOWN)
		isAnimating = false
		print("이제 다시 애니메이션을 실행할 수 있습니다.")
	end
end

--// 모든 플레이어에게 채팅 감지 이벤트를 연결하는 함수 //--
local function setupPlayerChatListener(player)
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end

-- 게임에 이미 접속해 있는 플레이어들에게 이벤트 연결
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerChatListener(player)
end

-- 새로 접속하는 플레이어들에게 이벤트 연결
Players.PlayerAdded:Connect(setupPlayerChatListener)

print("4. 채팅 명령어 '"..COMMAND.."'를 사용할 준비가 되었습니다.")
