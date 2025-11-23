-- Shared/Visualization/NetworkVisuals.lua
--[[
    NetworkVisuals.lua
    NetworkBuilder에 의해 이미 생성된 뉴런과 연결선 파트들을 찾아,
    새로운 파라미터 데이터에 맞춰 시각적 속성만 업데이트하는 모듈.
--]]

local NetworkVisuals = {}
NetworkVisuals.__index = NetworkVisuals

local POSITIVE_BIAS_COLOR = Color3.fromRGB(0, 150, 255)  -- 밝은 파랑
local NEGATIVE_BIAS_COLOR = Color3.fromRGB(255, 130, 0) -- 밝은 주황
local NEUTRAL_COLOR = Color3.fromRGB(128, 128, 128) -- 중간 회색

--- 생성자 함수
function NetworkVisuals.new(containerModel) 
    local self = setmetatable({}, NetworkVisuals)
    self.container = containerModel
    self.connections = {} -- 연결선(Beam) 캐시
    self.neurons = {}     -- 뉴런(Part) 캐시 (계층별로 저장)
    
    self:_indexExistingParts()
    
    return self
end

--- 컨테이너 안의 파트들을 미리 찾아 테이블에 저장해두는 내부 함수 (성능 향상)
function NetworkVisuals:_indexExistingParts()
    print("NetworkVisuals: 기존 네트워크 파트(뉴런, 연결선)들을 인덱싱합니다...")
    
    for _, child in ipairs(self.container:GetChildren()) do
        if child:IsA("Beam") then
            self.connections[child.Name] = child
        elseif child:IsA("Part") then
            -- 이름에서 레이어와 뉴런 인덱스를 추출 (예: "L2_N5")
            local layerIndex, neuronIndex = child.Name:match("L(%d+)_N(%d+)")
            layerIndex, neuronIndex = tonumber(layerIndex), tonumber(neuronIndex)
            
            if layerIndex and neuronIndex then
                -- 계층별로 뉴런을 저장
                if not self.neurons[layerIndex] then self.neurons[layerIndex] = {} end
                self.neurons[layerIndex][neuronIndex] = child
            end
        end
    end
    
    local connCount, neuronCount = 0, 0
    for _ in pairs(self.connections) do connCount = connCount + 1 end
    for _, layer in pairs(self.neurons) do
        for _ in pairs(layer) do neuronCount = neuronCount + 1 end
    end
    print(string.format("NetworkVisuals: 인덱싱 완료. 연결선 %d개, 뉴런 %d개를 찾았습니다.", connCount, neuronCount))
end

--- 새로운 파라미터로 캐싱된 파트들의 속성을 업데이트하는 메인 함수
function NetworkVisuals:updateWithParams(paramsData, networkConfig)
    if not paramsData or not paramsData.layers then return end
    if not networkConfig or not networkConfig.hidden then return end

    -- 1. 모든 가중치를 하나의 배열로 펼치고, 최대 절대값을 찾습니다.
    local maxAbsWeight = 0
    for _, layerData in ipairs(paramsData.layers) do
        for _, fromNeuronWeights in ipairs(layerData.weights) do
            for _, weight in ipairs(fromNeuronWeights) do
                if math.abs(weight) > maxAbsWeight then
                    maxAbsWeight = math.abs(weight)
                end
            end
        end
    end
    if maxAbsWeight == 0 then maxAbsWeight = 1 end
    print(string.format("NetworkVisuals: 현재 에포크 최대 가중치 %.4f 기준으로 정규화합니다.", maxAbsWeight))

    -- 2. 레이어 구조 정의
    local layers = {networkConfig.input}
    for _, neuronCount in ipairs(networkConfig.hidden) do table.insert(layers, neuronCount) end
    table.insert(layers, networkConfig.output)

    -- 3. 파라미터 데이터를 순회하며 시각화 업데이트
    for layerIndex, layerData in ipairs(paramsData.layers) do
        
        -- 3-1. 가중치(Weights) 업데이트 (동적 정규화 적용)
        for fromNeuronIndex = 1, layers[layerIndex] do
            for toNeuronIndex = 1, layers[layerIndex + 1] do
                local beamName = string.format("Conn_L%d_N%d_to_L%d_N%d", layerIndex, fromNeuronIndex, layerIndex + 1, toNeuronIndex)
                local beam = self.connections[beamName]
                if beam then
                    local weightValue = layerData.weights[fromNeuronIndex][toNeuronIndex]
                    local relativeStrength = math.abs(weightValue) / maxAbsWeight
                    
                    if weightValue >= 0 then beam.Color = ColorSequence.new(Color3.new(0, 1, 0)) else beam.Color = ColorSequence.new(Color3.new(1, 0, 0)) end
                    beam.Transparency = NumberSequence.new(0.9 - relativeStrength * 0.9)
                end
            end
        end
        
        -- 3-2. [복원됨] 편향(Biases) 업데이트
        local biases = layerData.biases
        local destinationLayerIndex = layerIndex + 1
        if self.neurons[destinationLayerIndex] then
            for neuronIndex = 1, #biases do
                local neuronPart = self.neurons[destinationLayerIndex][neuronIndex]
                if neuronPart then
                    local biasValue = biases[neuronIndex]
                    local t = math.clamp(math.abs(biasValue), 0, 1) -- 0~1 사이로 정규화
                    
                    if biasValue >= 0 then
                        neuronPart.Color = NEUTRAL_COLOR:Lerp(POSITIVE_BIAS_COLOR, t)
                    else
                        neuronPart.Color = NEUTRAL_COLOR:Lerp(NEGATIVE_BIAS_COLOR, t)
                    end
                end
            end
        end
    end
    
    print("NetworkVisuals: 가중치(연결선)와 편향(뉴런) 시각화를 모두 업데이트했습니다.")
end

return NetworkVisuals