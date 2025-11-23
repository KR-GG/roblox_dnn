--// 서비스 및 모듈 불러오기 //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ActivationFunctions = require(ReplicatedStorage.Shared.CoreLogic.ActivationFunctions)
local PerceptronMath = require(ReplicatedStorage.Shared.CoreLogic.PerceptronMath)
local PerceptronVisuals = require(ReplicatedStorage.Shared.Visualization.PerceptronVisuals)
local UIManager = require(ReplicatedStorage.Shared.UI.UIManager)
local ActivationGraphUI = require(ReplicatedStorage.Shared.UI.ActivationGraphUI)
local MapService = require(ReplicatedStorage.Shared.Services.MapService)
--- [추가] 계산 애니메이션 모듈을 불러옵니다.
local CalculationVisualizer = require(ReplicatedStorage.Shared.Visualization.CalculationVisualizer)

--// 변수 선언 //--
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local activationFuncs = { "Sigmoid", "Tanh", "ReLU", "Step" }
local currentFuncIndex = 1

local state = {
	inputs = { x1 = 1, x2 = 0, x3 = 1 },
	weights = { x1 = 0.5, x2 = -0.5, x3 = 0.5 },
	bias = 0.1,
	target = 1,
	loss = 0,
	activationName = activationFuncs[currentFuncIndex]
}

local parameterKeyMap = { w1 = "x1", w2 = "x2", w3 = "x3" }

-- GUI 및 모듈 인스턴스 변수
local visuals, ui, graphUI, lossCurve
local workspaceParts = {} -- [추가] workspaceParts를 더 높은 스코프에 선언

--- [추가] 가장 최근 계산 결과를 저장할 변수
local lastOutput = 0
local lastPreActivationSum = 0


--// 함수 정의 //--

local function onNodeClicked() CalculationVisualizer.playAnimation(workspaceParts, state, lastPreActivationSum, lastOutput) end

local function updateEverything()
	local currentActivationFunc = ActivationFunctions[state.activationName]
	local output, preActivationSum = PerceptronMath.calculateOutput(state.inputs, state.weights, state.bias, currentActivationFunc)
	state.loss = PerceptronMath.calculateLoss(output, state.target)
	lastOutput = output; lastPreActivationSum = preActivationSum

	visuals:updateInputs(state.inputs); visuals:updateWeights(state.weights); visuals:updateBias(state.bias); visuals:updateOutput(output)
	ui:updateUIState({w1 = state.weights.x1, w2 = state.weights.x2, w3 = state.weights.x3, bias = state.bias, activationName = state.activationName, loss = state.loss})

	-- SurfaceGUI 업데이트 (텍스트 색상 반전 포함)
	local function getTextColor(value) return if value > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255) end
	local x1Value = state.inputs.x1; local x1Label = workspaceParts.x1.SurfaceGui.TextLabel; x1Label.Text = x1Value; x1Label.TextColor3 = getTextColor(x1Value)
	local x2Value = state.inputs.x2; local x2Label = workspaceParts.x2.SurfaceGui.TextLabel; x2Label.Text = x2Value; x2Label.TextColor3 = getTextColor(x2Value)
	local x3Value = state.inputs.x3; local x3Label = workspaceParts.x3.SurfaceGui.TextLabel; x3Label.Text = x3Value; x3Label.TextColor3 = getTextColor(x3Value)
	local yValue = output; local yLabel = workspaceParts.y.SurfaceGui.TextLabel; yLabel.Text = string.format("%.2f", yValue); yLabel.TextColor3 = getTextColor(yValue)
	local neuronLabel = workspaceParts.Neuron.SurfaceGui.TextLabel; neuronLabel.Text = string.format("%.2f", preActivationSum); neuronLabel.TextColor3 = getTextColor(output)

	graphUI:updateMarker(preActivationSum, output)
end

local function onInputPartClicked(partName)
	print(string.format("Input part '%s' clicked!", partName))

	-- state.inputs 테이블의 해당 값을 반전시킵니다 (0 -> 1, 1 -> 0).
	if state.inputs[partName] == 0 then
		state.inputs[partName] = 1
	else
		state.inputs[partName] = 0
	end

	-- 변경된 입력값으로 모든 것을 다시 계산하고 업데이트합니다.
	updateEverything()
end

--// 메인 초기화 함수 //--
local function Initialize()
	local currentMap = MapService.getCurrentMap()
	if not currentMap then error("PerceptronController 초기화 실패: 현재 맵을 찾을 수 없습니다.") return end
	local perceptronModel = currentMap:WaitForChild("Perceptron")

	-- workspaceParts 테이블 채우기
	workspaceParts.container = perceptronModel
	workspaceParts.x1 = perceptronModel:WaitForChild("x1"); workspaceParts.x2 = perceptronModel:WaitForChild("x2")
	workspaceParts.x3 = perceptronModel:WaitForChild("x3"); workspaceParts.Neuron = perceptronModel:WaitForChild("Neuron")
	workspaceParts.y = perceptronModel:WaitForChild("y")

	-- 모듈 인스턴스 생성
	visuals = PerceptronVisuals.new(workspaceParts)
	ui = UIManager.new(playerGui:WaitForChild("PerceptronControls"))
	graphUI = ActivationGraphUI.new(perceptronModel:WaitForChild("BlankPart"):WaitForChild("SurfaceGui"))

	-- UI 이벤트 연결
	ui.ParameterChanged.Event:Connect(function(parameterName, value)
		if parameterName == "bias" then state.bias = value else local stateKey = parameterKeyMap[parameterName] if stateKey then state.weights[stateKey] = value end end
		updateEverything()
	end)
	ui.ActivationChanged.Event:Connect(function() currentFuncIndex = (currentFuncIndex % #activationFuncs) + 1; state.activationName = activationFuncs[currentFuncIndex]; graphUI:drawGraph(state.activationName); updateEverything() end)

	--- [추가] ClickDetector 이벤트 연결
	workspaceParts.Neuron:WaitForChild("ClickDetector").MouseClick:Connect(onNodeClicked)
	workspaceParts.y:WaitForChild("ClickDetector").MouseClick:Connect(onNodeClicked)

	workspaceParts.x1:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x1") end)
	workspaceParts.x2:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x2") end)
	workspaceParts.x3:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x3") end)

	-- 프로그램 시작
	graphUI:drawGraph(state.activationName)
	updateEverything()
	ui:setFrameVisibilityBasedOnPosition(playerGui.PerceptronControls, perceptronModel:GetBoundingBox().p, 50)

	print("PerceptronController: 모든 기능이 성공적으로 초기화되었습니다.")
end

Initialize()

print("PerceptronController: 스크립트 로드 완료. ClientReady 신호를 기다립니다...")

