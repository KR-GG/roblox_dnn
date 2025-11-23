-- ReplicatedStorage/Shared/Visualization/CalculationVisualizer.lua

local TweenService = game:GetService("TweenService")
local CalculationVisualizer = {}

local isAnimating = false

local COLOR_DEFAULT = Color3.fromRGB(150, 150, 150)  -- 기본 상태 (중간 회색)
local COLOR_CALCULATING = Color3.fromRGB(255, 130, 0) -- 가중합 계산 중 (주황색)
local COLOR_ACTIVATING = Color3.fromRGB(200, 200, 200)  -- 활성화 함수 적용 중 (밝은 회색)

-- 애니메이션 재생 함수가 (forward / backward) 모드를 받도록 변경
function CalculationVisualizer.playAnimation(mode, workspaceParts, state, preActivationSum, output)
	if isAnimating then return end
	isAnimating = true

	local neuronPart = workspaceParts.Neuron
	local textLabel = neuronPart.CalculationDisplay.TextLabel
	textLabel.Text = ""; neuronPart.Color = COLOR_DEFAULT

	local _ = coroutine.wrap(function()
		if mode == "forward" then
			-- 1. [순전파] 입력 구슬 생성 및 이동
			local inputParts = {workspaceParts.x1, workspaceParts.x2, workspaceParts.x3}
			local inputValues = {state.inputs.x1, state.inputs.x2, state.inputs.x3}
			local orbs = {}
			for i, part in ipairs(inputParts) do
				local orb = Instance.new("Part"); orb.Shape = Enum.PartType.Ball; orb.Size = Vector3.new(1, 1, 1); orb.Material = Enum.Material.Neon; orb.Anchored = true; orb.CanCollide = false
				orb.Color = if inputValues[i] == 1 then Color3.new(1, 1, 0) else Color3.new(0.5, 0.5, 0)
				orb.Position = part.Position; orb.Parent = workspaceParts.container; table.insert(orbs, orb)
			end

			textLabel.Text = "Step 1: Forward Pass (Inputs traveling...)"
			task.wait(0.5)

			local tweenInfo = TweenInfo.new(1)
			for _, orb in ipairs(orbs) do TweenService:Create(orb, tweenInfo, {Position = neuronPart.Position}):Play() end
			task.wait(tweenInfo.Time); for _, orb in ipairs(orbs) do orb:Destroy() end

			-- 2. 가중합 계산 과정 표시
			neuronPart.Color = COLOR_CALCULATING
			textLabel.Text = "Step 2: Calculating Weighted Sum..."
			task.wait(1.5)
			textLabel.Text = string.format("(%.1f*%.1f)+(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f", state.inputs.x1, state.weights.x1, state.inputs.x2, state.weights.x2, state.inputs.x3, state.weights.x3, state.bias, preActivationSum)
			task.wait(2.5)

			-- 3. 활성화 함수 적용 과정 표시
			neuronPart.Color = COLOR_ACTIVATING
			textLabel.Text = "Step 3: Applying Activation Function..."
			task.wait(1.5)
			textLabel.Text = string.format("%s(%.2f) = %.2f", state.activationName, preActivationSum, output)
			task.wait(2.5)

			-- 4. 최종 결과 구슬을 출력으로 이동
			local outputOrb = Instance.new("Part"); outputOrb.Shape = Enum.PartType.Ball; outputOrb.Size = Vector3.new(1.5, 1.5, 1.5); outputOrb.Material = Enum.Material.Neon
			outputOrb.Anchored = true; outputOrb.CanCollide = false; outputOrb.Color = Color3.fromHSV(0.66, 1, math.max(output, 0.1))
			outputOrb.Position = neuronPart.Position; outputOrb.Parent = workspaceParts.container
			TweenService:Create(outputOrb, TweenInfo.new(0.5), {Position = workspaceParts.y.Position}):Play()
			task.wait(0.5); outputOrb:Destroy()

		elseif mode == "backward" then
			-- [신규] 역전파 애니메이션
			textLabel.Text = "Step 3: Backpropagation (Calculating error...)"

			-- 1. 붉은색 오차 구슬 생성 (출력 -> 뉴런)
			local errorOrb = Instance.new("Part"); errorOrb.Shape = Enum.PartType.Ball; errorOrb.Size = Vector3.new(1.5, 1.5, 1.5); errorOrb.Material = Enum.Material.Neon
			errorOrb.Anchored = true; errorOrb.CanCollide = false; errorOrb.Color = Color3.new(1, 0, 0)
			errorOrb.Position = workspaceParts.y.Position; errorOrb.Parent = workspaceParts.container

			TweenService:Create(errorOrb, TweenInfo.new(1), {Position = neuronPart.Position}):Play()
			task.wait(1)

			-- 2. 붉은색 구슬이 뉴런에 도달하면, 입력부로 흩어짐
			textLabel.Text = "Assigning 'blame' to each connection..."
			local inputParts = {workspaceParts.x1, workspaceParts.x2, workspaceParts.x3}
			local orbTweens = {}
			for _, part in ipairs(inputParts) do
				local backOrb = Instance.new("Part"); backOrb.Shape = Enum.PartType.Ball; backOrb.Size = Vector3.new(1, 1, 1); backOrb.Material = Enum.Material.Neon
				backOrb.Anchored = true; backOrb.CanCollide = false; backOrb.Color = Color3.new(1, 0.2, 0.2)
				backOrb.Position = neuronPart.Position; backOrb.Parent = workspaceParts.container

				local tween = TweenService:Create(backOrb, TweenInfo.new(1), {Position = part.Position})
				tween:Play()
				table.insert(orbTweens, tween)
			end

			-- 3. 연결선(Beam)을 붉게 반짝임
			local beams = {workspaceParts.x1:FindFirstChildOfClass("Beam"), workspaceParts.x2:FindFirstChildOfClass("Beam"), workspaceParts.x3:FindFirstChildOfClass("Beam")}
			for _, beam in ipairs(beams) do
				if beam then
					local originalColor = beam.Color
					beam.Color = ColorSequence.new(Color3.new(1, 0, 0))
					task.wait(0.3)
					beam.Color = originalColor
				end
			end

			-- 4. 애니메이션 완료 후 정리
			task.wait(1); errorOrb:Destroy(); for _, orb in ipairs(orbTweens) do orb.Parent:Destroy() end
		end

		-- 5. 원래 상태로 복귀
		neuronPart.Color = COLOR_DEFAULT
		textLabel.Text = ""
		isAnimating = false
	end)()
end

return CalculationVisualizer