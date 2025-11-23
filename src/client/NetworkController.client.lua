-- StarterPlayerScripts/NetworkController.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 모듈 불러오기
local NetworkUIManager = require(ReplicatedStorage.Shared.UI.NetworkUIManager)
local NetworkBuilder = require(ReplicatedStorage.Shared.Visualization.NetworkBuilder)
local NetworkVisuals = require(ReplicatedStorage.Shared.Visualization.NetworkVisuals)
local MapService = require(ReplicatedStorage.Shared.Services.MapService)

--// 서버의 맵 로드가 완료될 때까지 기다립니다. (안정성 확보) //--
local currentMapValue = ReplicatedStorage:WaitForChild("CurrentMapValue")
if not currentMapValue.Value then
	print("NetworkController: 서버의 맵 로드를 기다립니다...")
	currentMapValue.Changed:Wait()
end
print("NetworkController: 서버 맵 준비 완료, 컨트롤러 초기화 시작.")

-- Remote Functions
local fetchApiDataFunction = ReplicatedStorage.RemoteFunctions:WaitForChild("FetchApiData")

-- GUI 및 플레이어 객체
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local networkGui = playerGui:WaitForChild("NetworkControls")

-- UIManager 인스턴스 생성
local ui = NetworkUIManager.new(networkGui)

-- 데이터셋 기본 정보
local DATASET_CONFIG = {
	XOR = { input = 2, output = 1 },
	IRIS = { input = 4, output = 3 },
	MNIST = { input = 784, output = 10 }, -- 시각화용으로는 28로 축소될 것임
	PRICE = { input = 8, output = 1 }
}

-- Mapping Tables
local datasetMap = { ["MNIST"] = "M", ["IRIS"] = "I", ["XOR"] = "F", ["PRICE"] = "C" }
local NEURON_TO_API_MAP = { [1] = "0", [2] = "1", [4] = "2", [8] = "3", [16] = "4" }

--// [수정] 애플리케이션의 모든 상태를 관리하는 중앙 테이블 //--
local state = {
	userSelection = {
		dataset = "XOR",
		depth = 1,
		activation = "Sigmoid",
	},
	apiConfig = nil,          -- API 요청에 사용할 실제 전체 설정
	visualConfig = nil,       -- 시각화에 사용할 축소된 설정
	hiddenLayersString = "",
	visuals = nil             -- NetworkVisuals 인스턴스
}

--// UIManager로부터 오는 신호(이벤트)에 연결 //--

ui.DatasetSelected.Event:Connect(function(datasetName)
	state.userSelection.dataset = datasetName
end)

ui.DepthSelected.Event:Connect(function(depth)
	state.userSelection.depth = depth
	ui:updateNodeSetVisibility(depth)
end)

ui.ActivationSelected.Event:Connect(function(activationName)
	state.userSelection.activation = activationName
end)

local function getGraphData()
	local paramsRequest = ui:returnConfig()
	local upperDataset = string.upper(paramsRequest.dataset)
	paramsRequest.dataset = datasetMap[upperDataset]
	paramsRequest.hidden_layers = state.hiddenLayersString
	paramsRequest.case = 1
	task.spawn(function()
		local success, dataOrError = fetchApiDataFunction:InvokeServer("/data", paramsRequest)

		if success then
			print("✅ 성공: 그래프 데이터를 받아왔습니다.")
			ui:updateGraphs(dataOrError)
		else
			warn("❌ 실패: 서버로부터 에러 메시지를 받았습니다:", dataOrError)
		end
	end)
end

ui.CreateNetworkClicked.Event:Connect(function()
	print("네트워크 생성 버튼 클릭됨!")
	
	getGraphData()

	local hidden_nodes = {}
	for i = 1, state.userSelection.depth do
		local configFrame = networkGui.CreateFrame.NodeSetFrame:FindFirstChild("Layer" .. i .. "_Config")
		if configFrame then
			local dropdownText = configFrame.DropdownFrame.CurrentSelection.TextLabel
			table.insert(hidden_nodes, tonumber(dropdownText.Text) or 1)
		end
	end

	local upperDataset = string.upper(state.userSelection.dataset)
	state.apiConfig = {
		input = DATASET_CONFIG[upperDataset].input,
		output = DATASET_CONFIG[upperDataset].output,
		hidden = hidden_nodes
	}
	state.visualConfig = table.clone(state.apiConfig)
	if upperDataset == "MNIST" then
		state.visualConfig.input = 28
	end

	local api_node_strings = {}
	for _, node_count in ipairs(hidden_nodes) do
		table.insert(api_node_strings, NEURON_TO_API_MAP[node_count] or "0")
	end
	state.hiddenLayersString = table.concat(api_node_strings, "")

	local currentMap = MapService.getCurrentMap()
	if not currentMap then return end

	local visualNetworkContainer = currentMap:WaitForChild("VisualNetwork")
	NetworkBuilder.build(state.visualConfig, visualNetworkContainer)
	state.visuals = NetworkVisuals.new(visualNetworkContainer)

	ui:updateConfig(state.userSelection)
	ui:setFrameVisibility("CreateFrame", false)
	ui:setFrameVisibility("ControlFrame", true)
end)

ui.EpochChanged.Event:Connect(function(currentEpoch)
	if not state.apiConfig or not state.visuals then
		warn("네트워크가 생성되지 않았습니다. 'Create Network' 버튼을 먼저 눌러주세요.")
		return
	end

	local paramsRequest = ui:returnConfig()
	local upperDataset = string.upper(paramsRequest.dataset)
	paramsRequest.dataset = datasetMap[upperDataset]
	paramsRequest.hidden_layers = state.hiddenLayersString
	paramsRequest.case = 1

	task.spawn(function()
		local success, dataOrError = fetchApiDataFunction:InvokeServer("/params", paramsRequest)

		if success then
			print("✅ 성공: 구조화된 파라미터 데이터를 받았습니다.")

			local visualData = dataOrError
			if upperDataset == "MNIST" then
				local trimmedData = { layers = {} }
				local originalFirstLayer = dataOrError.layers[1]
				local trimmedFirstLayerWeights = {}
				for i = 1, math.min(state.visualConfig.input, #originalFirstLayer.weights) do
					table.insert(trimmedFirstLayerWeights, originalFirstLayer.weights[i])
				end
				table.insert(trimmedData.layers, { weights = trimmedFirstLayerWeights, biases = originalFirstLayer.biases })
				for i = 2, #dataOrError.layers do
					table.insert(trimmedData.layers, dataOrError.layers[i])
				end
				visualData = trimmedData
			end

			state.visuals:updateWithParams(visualData, state.visualConfig)
		else
			warn("❌ 실패: 서버로부터 에러 메시지를 받았습니다:", dataOrError)
		end
	end)
end)



--// 초기화 //--
ui:updateNodeSetVisibility(state.userSelection.depth)
ui:updateConfig(state.userSelection)

local function initializeUIVisibility()
	local currentMap = MapService.getCurrentMap()
	if not currentMap then
		warn("초기화 실패: 현재 맵을 찾을 수 없습니다.")
		return 
	end

	-- 1. 먼저 'VisualNetwork' 모델이 복제될 때까지 기다립니다.
	local visualNetwork = currentMap:WaitForChild("VisualNetwork")

	-- 2. [가장 중요한 부분] 그 다음, 'VisualNetwork' 모델 안에 'PrimaryPart'라는 이름의 자식 객체가
	--    나타날 때까지 최대 5초간 기다립니다.
	local primaryPart = visualNetwork:WaitForChild("PrimaryPart", 5)

	if primaryPart then
		-- 3. PrimaryPart를 성공적으로 찾았으면, 그 위치를 사용합니다.
		local targetPosition = primaryPart.Position
		print("UI 가시성 기준 위치를 VisualNetwork의 PrimaryPart로 성공적으로 설정했습니다.")
		ui:setFrameVisibilityBasedOnPosition(networkGui, targetPosition, 50)
	else
		-- 이 경고는 이제 정말로 PrimaryPart가 없거나, 5초 안에 복제되지 않았을 때만 뜹니다.
		warn("초기화 경고: VisualNetwork는 찾았으나 그 안에서 PrimaryPart를 5초 내에 찾지 못했습니다.")
		-- Fallback: 맵 자체의 PrimaryPart를 사용
		local fallbackPos = currentMap.PrimaryPart and currentMap.PrimaryPart.Position or Vector3.new(0,0,0)
		ui:setFrameVisibilityBasedOnPosition(networkGui, fallbackPos, 50)
	end
end

-- 맵 준비 신호를 받은 후에만 UI 위치 설정을 시도합니다.
initializeUIVisibility()
--------------------------------------------------------------------

ui:setFrameVisibility("CreateFrame", true)
ui:setFrameVisibility("ControlFrame", false) -- 처음에는 ControlFrame을 숨깁니다.