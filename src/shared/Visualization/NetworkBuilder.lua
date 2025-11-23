-- ReplicatedStorage/Shared/Visualization/NetworkBuilder.lua

local NetworkBuilder = {}

--// 설정값 //--
local NODE_SIZE = 4
local LAYER_SPACING = 20 -- 레이어 사이의 거리
local NODE_SPACING = 4   -- 같은 레이어 내 노드 사이의 거리

--// 메인 함수: 설계도와 컨테이너를 받아 네트워크를 구축 //--
function NetworkBuilder.build(config, container)
    -- 1. 컨테이너가 유효한지 확인
    if not container or not container:IsA("Model") then
        warn("NetworkBuilder Error: 네트워크를 생성할 유효한 컨테이너 모델이 전달되지 않았습니다.")
        return
    end
 
	-- 2. 기준 위치를 '먼저' 가져옵니다. PrimaryPart가 없으면 에러 처리합니다.
	local primaryPart = container.PrimaryPart
	local basePosition
	if not primaryPart or not primaryPart:IsA("BasePart") then
		warn(string.format("NetworkBuilder Error: '%s' 모델에 PrimaryPart가 설정되어 있지 않아 위치를 결정할 수 없습니다.", container.Name))
		-- Fallback: 임시로 모델의 월드 중심 사용 (하지만 PrimaryPart 설정을 권장)
		basePosition = container:GetBoundingBox().p 
	else
		basePosition = primaryPart.Position
	end

	-- 3. 내용물을 지울 때, PrimaryPart는 제외하고 삭제합니다.
	print(string.format("NetworkBuilder: '%s' 컨테이너 내부를 비우고 새로 빌드를 시작합니다. (PrimaryPart 제외)", container.Name))
	for _, child in ipairs(container:GetChildren()) do
		-- PrimaryPart가 아니거나 이름이 PrimaryPart가 아니면 삭제
		if child ~= primaryPart and child.Name ~= "PrimaryPart" then 
			child:Destroy()
		end
	end
	
    -- 4. 전체 레이어 구조를 하나의 테이블로 통합
    local allLayers = {}
    table.insert(allLayers, config.input)
    for _, hiddenCount in ipairs(config.hidden) do
        table.insert(allLayers, hiddenCount)
    end
    table.insert(allLayers, config.output)
    
    local allNodeParts = {}

    -- 네트워크의 전체 크기 계산
    local totalNetworkWidth = (#allLayers - 1) * LAYER_SPACING
    local maxNodesInLayer = 0
    for _, nodeCount in ipairs(allLayers) do
        if nodeCount > maxNodesInLayer then maxNodesInLayer = nodeCount end
    end
    local maxLayerHeight = (maxNodesInLayer - 1) * NODE_SPACING
    
    -- 5. 모든 노드(파트) 생성
    for layerIndex, nodeCount in ipairs(allLayers) do
        allNodeParts[layerIndex] = {}
        local layerXPosition = (layerIndex - 1) * LAYER_SPACING - (totalNetworkWidth / 2)
        
        for nodeIndex = 1, nodeCount do
            local layerHeight = (nodeCount - 1) * NODE_SPACING
            local nodeYPosition = (nodeIndex - 1) * NODE_SPACING - (layerHeight / 2)
            
            local node = Instance.new("Part")
            node.Name = string.format("Neuron_L%d_N%d", layerIndex, nodeIndex)
            node.Shape = Enum.PartType.Ball
            node.Size = Vector3.new(NODE_SIZE, NODE_SIZE, NODE_SIZE)
            
            --- [수정됨] 미리 저장해둔 'basePosition' 변수를 사용하여 위치를 계산합니다.
            node.Position = basePosition + Vector3.new(layerXPosition, nodeYPosition + maxLayerHeight / 2 + NODE_SIZE, 0)
            
            node.Anchored = true
            node.Color = Color3.fromHSV((layerIndex - 1) / #allLayers, 0.8, 0.9)
            node.Parent = container
            
            local attachment = Instance.new("Attachment")
            attachment.Parent = node
            
            table.insert(allNodeParts[layerIndex], node)
        end
    end

    -- 6. 모든 연결(빔) 생성
    for layerIndex = 2, #allNodeParts do
        local fromLayerIndex = layerIndex - 1
        local toLayerIndex = layerIndex
        
        for fromNodeIndex, prevNode in ipairs(allNodeParts[fromLayerIndex]) do
            for toNodeIndex, currentNode in ipairs(allNodeParts[toLayerIndex]) do
                local beam = Instance.new("Beam")
                beam.Name = string.format("Conn_L%d_N%d_to_L%d_N%d", fromLayerIndex, fromNodeIndex, toLayerIndex, toNodeIndex)
                beam.Attachment0 = prevNode.Attachment
                beam.Attachment1 = currentNode.Attachment
                beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
                beam.LightEmission = 0.2
                beam.Transparency = NumberSequence.new(0.8)
                beam.Width0 = 0.2
                beam.Width1 = 0.2
                beam.Parent = container
            end
        end
    end
    
    print("신경망 생성 완료:", #allLayers, "개의 레이어")
end

return NetworkBuilder