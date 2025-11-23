--[[
    MatrixVisualizer.lua (Final Corrected Version)
    'Matrix Lab'의 2-2-1 네트워크 튜토리얼 전용 애니메이션 모듈.
    [수정] GUI 경로를 'SurfaceGui'에서 'CalculationDisplay'로
    정확하게 복원합니다.
--]]

local TweenService = game:GetService("TweenService")
local MatrixVisualizer = {}

local isAnimating = false
local COLOR_DEFAULT = Color3.fromRGB(150, 150, 150)
local COLOR_CALC = Color3.fromRGB(255, 130, 0)
local COLOR_ACT = Color3.fromRGB(200, 200, 200)

-- 3D 공간에서 오브(구슬) 애니메이션을 재생하는 헬퍼 함수
local function playOrbAnimation(startPart, endPart, color, duration)
	if not startPart or not endPart then return end
	local orb = Instance.new("Part"); orb.Shape = Enum.PartType.Ball; orb.Size = Vector3.new(1.2, 1.2, 1.2); orb.Material = Enum.Material.Neon
	orb.Anchored = true; orb.CanCollide = false; orb.Color = color
	orb.Position = startPart.Position; orb.Parent = startPart.Parent
	local tween = TweenService:Create(orb, TweenInfo.new(duration), {Position = endPart.Position})
	tween:Play()
	task.wait(duration)
	orb:Destroy()
end

--- [신규 복원] 빌보드 GUI에 계산 텍스트를 표시하는 함수
function MatrixVisualizer.showCalculationText(neuronPart, text, duration)
	if isAnimating or not neuronPart or not neuronPart:FindFirstChild("CalculationDisplay") then return end
	isAnimating = true

	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = text
	neuronPart.Color = COLOR_CALC

	task.wait(duration)

	textLabel.Text = ""
	neuronPart.Color = COLOR_DEFAULT
	isAnimating = false
end

--- [신규 복원] 활성화 애니메이션 (단일 뉴런용)
function MatrixVisualizer.playActivation(neuronPart, output, yPart)
	if isAnimating or not neuronPart or not neuronPart:FindFirstChild("CalculationDisplay") then return end
	isAnimating = true

	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = "Activating..."
	neuronPart.Color = COLOR_ACT
	task.wait(1.5)
	textLabel.Text = string.format("= %.2f", output)

	-- 최종 결과가 출력으로 이동
	coroutine.wrap(playOrbAnimation)(
		neuronPart, yPart, 
		Color3.fromHSV(0.66, 1, math.max(output, 0.1)), 
		0.5
	)
	task.wait(0.5)

	textLabel.Text = ""
	neuronPart.Color = COLOR_DEFAULT
	isAnimating = false
end


--- 순전파 애니메이션 (입력 -> 은닉층)
function MatrixVisualizer.playForwardPass(workspaceParts, inputs)
	if isAnimating then return end; isAnimating = true

	local h1 = workspaceParts.h1; local h2 = workspaceParts.h2
	local text1 = h1.CalculationDisplay.TextLabel; local text2 = h2.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용
	text1.Text = "Receiving inputs..."; text2.Text = "Receiving inputs..."

	coroutine.wrap(playOrbAnimation)(workspaceParts.x1, h1, if inputs.x1 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 1)
	coroutine.wrap(playOrbAnimation)(workspaceParts.x1, h2, if inputs.x1 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 1)
	coroutine.wrap(playOrbAnimation)(workspaceParts.x2, h1, if inputs.x2 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 1)
	coroutine.wrap(playOrbAnimation)(workspaceParts.x2, h2, if inputs.x2 == 1 then Color3.new(1,1,0) else Color3.new(0.5,0.5,0), 1)

	task.wait(1.2)
	text1.Text = ""; text2.Text = ""
	isAnimating = false
end

--- 행렬 계산 시각화 (빌보드 GUI)
function MatrixVisualizer.showMatrixCalculation(workspaceParts, sums_h)
	if isAnimating then return end; isAnimating = true

	local h1 = workspaceParts.h1; local h2 = workspaceParts.h2
	local text1 = h1.CalculationDisplay.TextLabel; local text2 = h2.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용

	text1.Text = "Calculating Sum 1..."; text2.Text = "Calculating Sum 2..."
	h1.Color = COLOR_CALC; h2.Color = COLOR_CALC
	task.wait(1.5)

	text1.Text = string.format("Sum = %.2f", sums_h.h1)
	text2.Text = string.format("Sum = %.2f", sums_h.h2)
	h1.SurfaceGui.TextLabel.Text = string.format("%.2f", sums_h.h1)
	h2.SurfaceGui.TextLabel.Text = string.format("%.2f", sums_h.h2)
	task.wait(3)

	text1.Text = ""; text2.Text = ""
	h1.Color = COLOR_DEFAULT; h2.Color = COLOR_DEFAULT
	isAnimating = false
end

--- 은닉층 활성화 애니메이션 (두 뉴런 동시)
function MatrixVisualizer.playHiddenActivation(workspaceParts, acts_h)
	if isAnimating then return end; isAnimating = true

	local h1 = workspaceParts.h1; local h2 = workspaceParts.h2
	local text1 = h1.CalculationDisplay.TextLabel; local text2 = h2.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용

	text1.Text = "Activating..."; text2.Text = "Activating..."
	h1.Color = COLOR_ACT; h2.Color = COLOR_ACT
	task.wait(1.5)

	text1.Text = string.format("= %.2f", acts_h.h1)
	text2.Text = string.format("= %.2f", acts_h.h2)
	h1.SurfaceGui.TextLabel.Text = string.format("%.2f", acts_h.h1)
	h2.SurfaceGui.TextLabel.Text = string.format("%.2f", acts_h.h2)
	task.wait(2)

	text1.Text = ""; text2.Text = ""
	h1.Color = COLOR_DEFAULT; h2.Color = COLOR_DEFAULT
	isAnimating = false
end

--- 출력층 순전파 애니메이션
function MatrixVisualizer.playOutputPass(workspaceParts, acts_h)
	if isAnimating then return end; isAnimating = true

	local y = workspaceParts.y
	local text_y = y.CalculationDisplay.TextLabel
	text_y.Text = "Receiving hidden inputs..."

	coroutine.wrap(playOrbAnimation)(workspaceParts.h1, y, Color3.fromHSV(0.66, 1, math.max(acts_h.h1, 0.1)), 1)
	coroutine.wrap(playOrbAnimation)(workspaceParts.h2, y, Color3.fromHSV(0.66, 1, math.max(acts_h.h2, 0.1)), 1)

	task.wait(1.2)
	text_y.Text = ""
	isAnimating = false
end

--- 역전파 애니메이션 ---
function MatrixVisualizer.playBackwardPass(workspaceParts)
	if isAnimating then return end; isAnimating = true

	local h1 = workspaceParts.h1; local h2 = workspaceParts.h2; local y = workspaceParts.y
	local text1 = h1.CalculationDisplay.TextLabel; local text2 = h2.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용
	local text_y = y.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용

	text_y.Text = "3. Backpropagation: Tracing error..."
	y.Color = COLOR_CALC

	coroutine.wrap(playOrbAnimation)(y, h1, Color3.new(1, 0, 0), 1)
	coroutine.wrap(playOrbAnimation)(y, h2, Color3.new(1, 0, 0), 1)
	task.wait(1.2)

	y.Color = COLOR_DEFAULT -- [수정] y.Text는 아래에서 초기화
	text1.Text = "Assigning Blame..."; text2.Text = "Assigning Blame..."

	coroutine.wrap(playOrbAnimation)(h1, workspaceParts.x1, Color3.new(1, 0.2, 0.2), 1)
	coroutine.wrap(playOrbAnimation)(h1, workspaceParts.x2, Color3.new(1, 0.2, 0.2), 1)
	coroutine.wrap(playOrbAnimation)(h2, workspaceParts.x1, Color3.new(1, 0.2, 0.2), 1)
	coroutine.wrap(playOrbAnimation)(h2, workspaceParts.x2, Color3.new(1, 0.2, 0.2), 1)

	local allBeams = {}
	if workspaceParts.container then
		for _, child in ipairs(workspaceParts.container:GetChildren()) do
			if child:IsA("Beam") then table.insert(allBeams, child) end
		end
	end
	for _, beam in ipairs(allBeams) do beam.Color = ColorSequence.new(Color3.new(1, 0, 0)) end
	task.wait(0.5)

	task.wait(0.7)
	text1.Text = ""; text2.Text = ""; text_y.Text = "" -- [수정] y.Text 여기서 초기화
	isAnimating = false
end

--- 에포크 루프 애니메이션 ---
function MatrixVisualizer.playEpochLoop(workspaceParts)
	if isAnimating then return end; isAnimating = true

	local allBeams = {}
	if workspaceParts.container then
		for _, child in ipairs(workspaceParts.container:GetChildren()) do
			if child:IsA("Beam") then table.insert(allBeams, child) end
		end
	end

	local text1 = workspaceParts.h1.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용
	local text2 = workspaceParts.h2.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용
	local text_y = workspaceParts.y.CalculationDisplay.TextLabel -- [복원] 'CalculationDisplay' 사용
	text1.Text = "Training..."; text2.Text = "Training..."; text_y.Text = "Looping..."

	for i = 1, 5 do
		for _, beam in ipairs(allBeams) do beam.Color = ColorSequence.new(Color3.new(1,1,0)) end
		task.wait(0.15)
		for _, beam in ipairs(allBeams) do beam.Color = ColorSequence.new(Color3.new(1,0,0)) end
		task.wait(0.15)
	end

	text1.Text = ""; text2.Text = ""; text_y.Text = ""
	isAnimating = false
end

return MatrixVisualizer