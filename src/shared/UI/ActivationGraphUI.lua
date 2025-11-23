-- ReplicatedStorage/Shared/UI/ActivationGraphUI.lua

local ActivationFunctions = require(script.Parent.Parent.CoreLogic.ActivationFunctions)

local GraphUI = {}
GraphUI.__index = GraphUI

-- 설정값
local X_RANGE = 6 -- 그래프 x축 범위 (-3 to 3)
local NUM_SEGMENTS = 50 -- 그래프를 그릴 선 조각의 개수

function GraphUI.new(surfaceGui)
	local self = setmetatable({}, GraphUI)
	self.gui = surfaceGui
	self.background = surfaceGui:WaitForChild("Background")
	self.marker = self.background:WaitForChild("Marker")
	
	-- 기존 그래프 조각들을 지우기 위한 컨테이너
	self.graphContainer = Instance.new("Folder", self.background)
	self.graphContainer.Name = "GraphSegments"
	
	return self
end

-- 수학 좌표(x, y)를 GUI 좌표(UDim2)로 변환하는 함수
local function mapToUdim2(x, y)
	-- x: -5~5 -> 0~1
	-- y: -1~1 -> 1~0 (Roblox GUI의 Y좌표는 위가 0, 아래가 1이므로 반전)
	local scaleX = (x + (X_RANGE / 2)) / X_RANGE
	local scaleY = 1 - ((y + 1) / 2)
	return UDim2.fromScale(scaleX, scaleY)
end

-- 특정 활성화 함수 그래프를 그리는 함수
function GraphUI:drawGraph(functionName)
	self.graphContainer:ClearAllChildren() -- 기존 그래프 삭제
	
	local func = ActivationFunctions[functionName]
	if not func then return end
	
	for i = 0, NUM_SEGMENTS - 1 do
		local x1 = (i / NUM_SEGMENTS) * X_RANGE - (X_RANGE / 2)
		local x2 = ((i + 1) / NUM_SEGMENTS) * X_RANGE - (X_RANGE / 2)
		
		local y1 = func(x1)
		
		local segment = Instance.new("Frame")
		segment.BackgroundColor3 = Color3.fromRGB(0, 255, 127) -- 밝은 초록색
		segment.BorderSizePixel = 0
		segment.AnchorPoint = Vector2.new(0, 0.5)
		segment.Size = UDim2.fromScale((x2 - x1) / X_RANGE, 0.04)
		segment.Position = mapToUdim2(x1, y1)
		segment.Parent = self.graphContainer
	end
end

-- 현재 값 마커의 위치를 업데이트하는 함수
function GraphUI:updateMarker(inputValue, outputValue)
	if not self.marker.Visible then self.marker.Visible = true end
	self.marker.Position = mapToUdim2(inputValue, outputValue)
end

return GraphUI