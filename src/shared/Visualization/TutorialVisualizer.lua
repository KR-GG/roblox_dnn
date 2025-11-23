--[[
    TutorialVisualizer.lua
    'Forward' 방의 2입력 1출력 튜토리얼 전용 애니메이션 모듈.
    각 학습 단계를 위한 세분화된 애니메이션을 제공합니다.
--]]

local TweenService = game:GetService("TweenService")
local TutorialVisualizer = {}

local isAnimating = false
local COLOR_DEFAULT = Color3.fromRGB(150, 150, 150)
local COLOR_CALCULATING = Color3.fromRGB(255, 130, 0)
local COLOR_ACTIVATING = Color3.fromRGB(200, 200, 200)

local function playOrbAnimation(startPart, endPart, color, duration)
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball; orb.Size = Vector3.new(1.2, 1.2, 1.2); orb.Material = Enum.Material.Neon
	orb.Anchored = true; orb.CanCollide = false
	orb.Color = color
	orb.Position = startPart.Position
	orb.Parent = startPart.Parent

	local tween = TweenService:Create(orb, TweenInfo.new(duration), {Position = endPart.Position})
	tween:Play()
	tween.Completed:Wait()
	orb:Destroy()
end

--- [신규] 빌보드 GUI에 계산 텍스트를 표시하는 함수
function TutorialVisualizer.showCalculationText(neuronPart, text, duration)
	if isAnimating then return end
	isAnimating = true

	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = text
	neuronPart.Color = COLOR_CALCULATING

	task.wait(duration)

	textLabel.Text = ""
	neuronPart.Color = COLOR_DEFAULT
	isAnimating = false
end

--- [신규] 순전파 애니메이션
function TutorialVisualizer.playForwardPass(workspaceParts, inputs)
	if isAnimating then return end
	isAnimating = true

	local neuronPart = workspaceParts.Neuron
	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = "1. Forward Pass: Inputs traveling..."

	-- 두 입력이 동시에 뉴런으로 이동
	coroutine.wrap(playOrbAnimation)(
		workspaceParts.x1, neuronPart, 
		if inputs.x1 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 
		1
	)
	coroutine.wrap(playOrbAnimation)(
		workspaceParts.x2, neuronPart, 
		if inputs.x2 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 
		1
	)
	task.wait(1.2) -- 오브 이동 완료 대기
	textLabel.Text = ""
	isAnimating = false
end

--- [신규] 활성화 애니메이션
function TutorialVisualizer.playActivation(neuronPart, output, yPart)
	if isAnimating then return end
	isAnimating = true

	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = "Applying Activation Function..."
	neuronPart.Color = COLOR_ACTIVATING
	task.wait(1.5)
	textLabel.Text = string.format("= %.2f", output)

	-- 최종 결과가 출력으로 이동
	playOrbAnimation(
		neuronPart, yPart, 
		Color3.fromHSV(0.66, 1, math.max(output, 0.1)), 
		0.5
	)
	task.wait(0.5)

	textLabel.Text = ""
	neuronPart.Color = COLOR_DEFAULT
	isAnimating = false
end

--- [신규] 역전파 애니메이션
function TutorialVisualizer.playBackwardPass(workspaceParts)
	if isAnimating then return end
	isAnimating = true

	local neuronPart = workspaceParts.Neuron
	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = "3. Backpropagation: Tracing error..."

	-- 붉은색 오차 구슬이 뒤로 이동
	coroutine.wrap(playOrbAnimation)(workspaceParts.y, neuronPart, Color3.new(1,0,0), 1)
	task.wait(1.2)

	textLabel.Text = "Assigning 'blame'..."
	-- 붉은색 구슬이 뉴런에서 입력부로 흩어짐
	coroutine.wrap(playOrbAnimation)(neuronPart, workspaceParts.x1, Color3.new(1,0.2,0.2), 1)
	coroutine.wrap(playOrbAnimation)(neuronPart, workspaceParts.x2, Color3.new(1,0.2,0.2), 1)

	-- 빔을 붉게 반짝임
	local beams = {workspaceParts.x1:FindFirstChildOfClass("Beam"), workspaceParts.x2:FindFirstChildOfClass("Beam")}
	for _, beam in ipairs(beams) do
		if beam then
			local originalColor = beam.Color
			beam.Color = ColorSequence.new(Color3.new(1, 0, 0))
			task.wait(0.3)
			beam.Color = originalColor
		end
	end

	task.wait(1.2)
	textLabel.Text = ""
	isAnimating = false
end

return TutorialVisualizer

