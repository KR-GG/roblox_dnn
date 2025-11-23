-- ReplicatedStorage/Shared/UI/NetworkUIManager.lua 

local RunService = game:GetService("RunService")
local UIManager = {}
UIManager.__index = UIManager

function UIManager.new(gui)
	local self = setmetatable({}, UIManager)
	self.gui = gui

	-- GUI 객체 참조
	self.createFrame = gui:WaitForChild("CreateFrame")
	self.controlFrame = gui:WaitForChild("ControlFrame")
	self.datasetFrame = self.createFrame:WaitForChild("DatasetSelectFrame")
	self.depthFrame = self.createFrame:WaitForChild("DepthSetFrame")
	self.activationFrame = self.createFrame:WaitForChild("ActivationFrame")
	self.nodeSetFrame = self.createFrame:WaitForChild("NodeSetFrame")
	self.createButton = self.createFrame:WaitForChild("CreateButton")
	self.createUpButton = self.controlFrame:WaitForChild("CreateUpButton")
	self.createDownButton = self.controlFrame:WaitForChild("CreateDownButton")
	self.epochText = self.controlFrame:WaitForChild("EpochData")
	self.epochRightButton = self.controlFrame:WaitForChild("RightButton")
	self.epochLeftButton = self.controlFrame:WaitForChild("LeftButton")

	-- 그래프 프레임 참조 추가
	self.accuracyGraphFrame = self.controlFrame:WaitForChild("AccuracyGraph")
	self.lossGraphFrame = self.controlFrame:WaitForChild("LossGraph")

	-- 외부로 보낼 신호(이벤트) 생성 (NodeCountChanged 제외)
	self.DatasetSelected = Instance.new("BindableEvent")
	self.DepthSelected = Instance.new("BindableEvent")
	self.ActivationSelected = Instance.new("BindableEvent")
	self.CreateNetworkClicked = Instance.new("BindableEvent")
	self.EpochChanged = Instance.new("BindableEvent")

	self:_setupSelectionEvents()
	self:_setupEpochButtons()

	return self
end

-- 버튼 그룹의 선택 효과를 관리하는 헬퍼 함수
function UIManager:_manageSelectionEffect(frame, eventToFire)
	local buttons = {}
	local originalColors = {}

	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextButton") then
			table.insert(buttons, child)
			originalColors[child] = { bg = child.BackgroundColor3, text = child.TextColor3 }
		end
	end

	local selectedColor = Color3.fromRGB(70, 130, 180)
	local selectedTextColor = Color3.fromRGB(255, 255, 255)

	for _, button in ipairs(buttons) do
		button.MouseButton1Click:Connect(function()
			for _, btn in ipairs(buttons) do
				btn.BackgroundColor3 = originalColors[btn].bg
				btn.TextColor3 = originalColors[btn].text
			end

			button.BackgroundColor3 = selectedColor
			button.TextColor3 = selectedTextColor

			local value = tonumber(button.Name) or button.Name
			eventToFire:Fire(value)
		end)
	end
end

-- 각종 버튼들의 클릭 이벤트를 설정하고 신호를 보냄
function UIManager:_setupSelectionEvents()
	self:_manageSelectionEffect(self.datasetFrame, self.DatasetSelected)
	self:_manageSelectionEffect(self.depthFrame, self.DepthSelected)
	self:_manageSelectionEffect(self.activationFrame, self.ActivationSelected)

	self.createButton.MouseButton1Click:Connect(function() 
		self.CreateNetworkClicked:Fire() 
	end)

	self.createUpButton.MouseButton1Click:Connect(function()
		self:setFrameVisibility("CreateFrame", true)
	end)
	self.createDownButton.MouseButton1Click:Connect(function()
		self:setFrameVisibility("CreateFrame", false)
	end)
end

-- 에포크 증가/감소 버튼 설정(epoch 범위 0 이상 10 이하로 제한)
function UIManager:_setupEpochButtons()
	self.epochRightButton.MouseButton1Click:Connect(function()
		local currentEpoch = tonumber(self.epochText.Text) or 0
		if currentEpoch < 10 then
			currentEpoch = currentEpoch + 1
			self.epochText.Text = tostring(currentEpoch)
			self.EpochChanged:Fire(currentEpoch)
		end
	end)

	self.epochLeftButton.MouseButton1Click:Connect(function()
		local currentEpoch = tonumber(self.epochText.Text) or 0
		if currentEpoch > 0 then
			currentEpoch = currentEpoch - 1
			self.epochText.Text = tostring(currentEpoch)
			self.EpochChanged:Fire(currentEpoch)
		end
	end)
end

-- 깊이에 따라 노드 설정 프레임들의 Visible 속성을 조절
function UIManager:updateNodeSetVisibility(depth)
	for i = 1, 4 do
		local configFrame = self.nodeSetFrame:FindFirstChild("Layer" .. i .. "_Config")
		if configFrame then
			configFrame.Visible = (i <= depth)
		end
	end
end

-- 프레임의 이름을 인자로 받아 visibility 설정을 온/오프
function UIManager:setFrameVisibility(frameName, isVisible)
	local frame = self.gui:FindFirstChild(frameName)
	if frame then
		frame.Visible = isVisible
		if frameName == "CreateFrame" then
			self.createUpButton.Visible = not isVisible
			self.createDownButton.Visible = isVisible
		end
	end
end

-- config 값을 받아서 UI 요소를 업데이트
function UIManager:updateConfig(config)
	self.controlFrame:WaitForChild("Row1Text").Text = config.dataset
	self.controlFrame:WaitForChild("Row2Text").Text = config.activation
	self.controlFrame:WaitForChild("EpochData").Text = 0
end

function UIManager:returnConfig()
	local currentDataset = self.controlFrame:WaitForChild("Row1Text").Text
	local currentActivation = self.controlFrame:WaitForChild("Row2Text").Text:lower()
	local currentEpoch = tonumber(self.controlFrame:WaitForChild("EpochData").Text) or 0
	return {
		dataset = currentDataset,
		activation = currentActivation,
		epochs = currentEpoch
	}
end

function UIManager:setFrameVisibilityBasedOnPosition(frame, targetPosition, threshold)
	if self.visibilityConnection then
		self.visibilityConnection:Disconnect()
		self.visibilityConnection = nil
	end

	self.visibilityConnection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local _, onScreen = camera:WorldToViewportPoint(targetPosition)
		local player = game.Players.LocalPlayer
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local characterPosition = player.Character.HumanoidRootPart.Position
			local distance = (characterPosition - targetPosition).Magnitude
			frame.Enabled = onScreen and distance < threshold
		else
			frame.Enabled = false
		end
	end)
end

-- [!!] 그래프를 그리기 위한 헬퍼 함수 (두 UDim2 스케일 좌표 사이에 선 그리기)
function UIManager:_drawLine(parent, pos1, pos2, color)
	local parentSize = parent.AbsoluteSize

	-- UDim2 스케일 값을 픽셀 기반 Vector2로 변환
	local p1 = Vector2.new(pos1.X.Scale * parentSize.X, pos1.Y.Scale * parentSize.Y)
	local p2 = Vector2.new(pos2.X.Scale * parentSize.X, pos2.Y.Scale * parentSize.Y)

	local distance = (p1 - p2).Magnitude
	local angle = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
	local midPoint = (p1 + p2) / 2

	-- 선으로 사용할 프레임 생성
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.Size = UDim2.new(0, distance, 0, 2) -- 굵기 2px
	line.Position = UDim2.fromOffset(midPoint.X, midPoint.Y) -- 픽셀 오프셋으로 위치 지정
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Rotation = math.deg(angle)
	line.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	line.BorderSizePixel = 0
	line.Parent = parent
end

-- [!!] 데이터 포인트를 기반으로 그래프를 그리는 헬퍼 함수
function UIManager:_drawGraph(graphFrame, dataPoints, graphType)
	-- 1. 기존 그래프 요소(점, 선) 삭제
	for _, child in ipairs(graphFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- 2. 데이터 유효성 검사 (최소 2개)
	if not dataPoints or #dataPoints < 2 then
		warn("그래프를 그리기에 데이터가 부족합니다: " .. graphType)
		return
	end

	-- 3. Y축 스케일링을 위한 최소/최대값 찾기
	local minY = dataPoints[1]
	local maxY = dataPoints[1]
	for _, val in ipairs(dataPoints) do
		if val < minY then minY = val end
		if val > maxY then maxY = val end
	end

	-- 모든 값이 같을 경우 (0으로 나누기 방지)
	if minY == maxY then
		minY = minY - 0.5
		maxY = maxY + 0.5
	end

	-- 4. 데이터 포인트를 UDim2 스케일(0~1) 좌표로 변환하는 함수
	local totalPoints = #dataPoints
	local xPadding = 0.05 -- 좌우 패딩 (5%)
	local yPadding = 0.1 -- 상하 패딩 (10%)

	local function getPosition(index, value)
		-- X축: (0+패딩) ~ (1-패딩) 사이
		local x = xPadding + ((index - 1) / (totalPoints - 1)) * (1 - 2 * xPadding)

		-- Y축: (0+패딩) ~ (1-패딩) 사이, UI 좌표계(위가 0)이므로 1에서 빼서 뒤집음
		local y = 1 - (yPadding + ((value - minY) / (maxY - minY)) * (1 - 2 * yPadding))

		-- 혹시 모를 범위 초과 방지
		y = math.clamp(y, 0.01, 0.99) 

		return UDim2.new(x, 0, y, 0)
	end

	-- 5. 점(Point) 생성 및 위치 저장
	local pointPositions = {}
	local graphColor = (graphType == "Accuracy") and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)

	for i, value in ipairs(dataPoints) do
		local pos = getPosition(i, value)
		table.insert(pointPositions, pos)

		-- 점(Frame) 생성
		local pointFrame = Instance.new("Frame")
		pointFrame.Name = "Point" .. i
		pointFrame.Size = UDim2.new(0, 5, 0, 5) -- 5x5 픽셀
		pointFrame.Position = pos
		pointFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- 중앙 정렬
		pointFrame.BackgroundColor3 = graphColor
		pointFrame.BorderSizePixel = 0
		pointFrame.Parent = graphFrame
	end

	-- 6. 점들 사이에 선(Line) 생성
	for i = 1, #pointPositions - 1 do
		local p1 = pointPositions[i]
		local p2 = pointPositions[i+1]

		self:_drawLine(graphFrame, p1, p2, graphColor)
	end
end


-- [!!] 외부에서 호출할 그래프 업데이트 공용 함수 (수정본)
function UIManager:updateGraphs(data)
	if not data then
		warn("updateGraphs: 데이터가 nil 입니다.")
		return
	elseif not data.loss or not data.accuracy then
		warn("updateGraphs: 유효하지 않은 데이터 형식입니다.")
		return
	end

	-- UI의 AbsoluteSize가 올바르게 계산되도록 별도 스레드에서 실행
	task.spawn(function()

		-- [!!] 중요: graphFrame의 AbsoluteSize.X가 0이 아닐 때까지 기다립니다.
		-- 이것은 ScreenGui나 ControlFrame이 실제로 화면에 보일 때까지 대기하는 효과입니다.
		while self.accuracyGraphFrame.AbsoluteSize.X == 0 do
			task.wait()
		end

		-- 이제 AbsoluteSize가 유효하므로 그래프를 그립니다.
		self:_drawGraph(self.accuracyGraphFrame, data.accuracy, "Accuracy")
		self:_drawGraph(self.lossGraphFrame, data.loss, "Loss")
	end)
end



return UIManager