-- shared/Animation/PropagationVFX.lua
-- 순전파, 역전파 과정의 모든 동적 애니메이션과 특수 효과(VFX)를 담당합니다.
--[[
playForwardPass(activations): TweenService를 이용해 순전파 데이터 흐름(빛의 펄스 이동, 노드 발화)을 애니메이션으로 보여줍니다.

playLossFeedback(outputNode): 오차 계산 시 '부조화스러운 에너지 파동' 효과를 재생합니다.

playBackwardPass(errorGradients): 붉은 빛이 역으로 전파되는 역전파 과정을 애니메이션으로 보여줍니다.

playWeightUpdateEffect(beam): 특정 빔이 업데이트되는 순간 깜빡이거나 굵기가 변하는 효과를 재생합니다.
]]--

local TweenService = game:GetService("TweenService")
local PropagationVFX = {}
local function new(partsTable)
    local self = {}
    self.parts = partsTable or {}
    return setmetatable(self, { __index = PropagationVFX })
end
function PropagationVFX:playForwardPass(activations)
    for layerIndex, layer in ipairs(activations) do
        for nodeIndex, activation in ipairs(layer) do
            local nodePart = self.parts.nodes[layerIndex] and self.parts.nodes[layerIndex][nodeIndex]
            if nodePart then
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local goal = { Transparency = 1 - math.min(math.abs(activation), 1) }
                local tween = TweenService:Create(nodePart, tweenInfo, goal)
                tween:Play()
                tween.Completed:Wait()
            end
        end
    end
end
function PropagationVFX:playLossFeedback(outputNode)
    if outputNode then
        local originalColor = outputNode.Color
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
        local goal = { Color = Color3.new(1, 0, 0) }
        local tween = TweenService:Create(outputNode, tweenInfo, goal)
        tween:Play()
        tween.Completed:Wait()
        outputNode.Color = originalColor
    end
end
function PropagationVFX:playBackwardPass(errorGradients)
    for layerIndex = #errorGradients, 1, -1 do
        local layer = errorGradients[layerIndex]
        for nodeIndex, gradient in ipairs(layer) do
            local nodePart = self.parts.nodes[layerIndex] and self.parts.nodes[layerIndex][nodeIndex]
            if nodePart then
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local goal = { Transparency = 1 - math.min(math.abs(gradient), 1) }
                local tween = TweenService:Create(nodePart, tweenInfo, goal)
                tween:Play()
                tween.Completed:Wait()
            end
        end
    end
end
function PropagationVFX:playWeightUpdateEffect(beam)
    if beam then
        local originalWidth0 = beam.Width0
        local originalWidth1 = beam.Width1
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        local goal = { Width0 = originalWidth0 * 1.5, Width1 = originalWidth1 * 1.5 }
        local tween = TweenService:Create(beam, tweenInfo, goal)
        tween:Play()
        tween.Completed:Wait()
        beam.Width0 = originalWidth0
        beam.Width1 = originalWidth1
    end
end
return PropagationVFX