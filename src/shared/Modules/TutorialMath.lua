--[[
    TutorialMath.lua
    'Forward' 방의 2입력 1출력 튜토리얼 전용 계산 모듈.
    순전파, 역전파, 경사 하강법을 100% Lua로 계산합니다.
--]]
local TutorialMath = {}

local ActivationFunctions = require(game:GetService("ReplicatedStorage").Shared.CoreLogic.ActivationFunctions)
local LEARNING_RATE = 0.2 -- 학습률 (2입력 모델은 조금 높여도 좋습니다)

--- 2입력 1출력 순전파 계산
function TutorialMath.calculateOutput(inputs, weights, bias, activationFunc)
	local sum = bias
	sum = sum + (inputs.x1 * weights.x1)
	sum = sum + (inputs.x2 * weights.x2)
	local output = activationFunc(sum)
	return output, sum
end

--- 활성화 함수 미분값
local function getActivationDerivative(funcName, output)
	if funcName == "Sigmoid" then return output * (1 - output)
	elseif funcName == "ReLU" then return if output > 0 then 1 else 0
	end
	return 0
end

--- 2입력 1출력 역전파 및 경사 하강법 실행
function TutorialMath.runBackpropagation(state, preActivationSum, output, target)
	local inputs = state.inputs
	local weights = state.weights
	local bias = state.bias

	local error = target - output
	local activationDerivative = getActivationDerivative(state.activationName, output)
	local delta = error * activationDerivative

	-- 2-Input Gradient Calculation
	local dw1 = delta * inputs.x1
	local dw2 = delta * inputs.x2
	local db = delta

	-- Update Weights
	local newWeights = {
		x1 = weights.x1 + (LEARNING_RATE * dw1),
		x2 = weights.x2 + (LEARNING_RATE * dw2),
	}
	local newBias = bias + (LEARNING_RATE * db)

	-- 업데이트된 새 가중치와 편향, 그리고 계산된 델타(delta) 값을 반환
	return newWeights, newBias, delta
end

--// --- 순전파(Forward Pass) 계산 ---

--- 1. 가중합(Weighted Sum)만 계산합니다.
function TutorialMath.calculateWeightedSum(inputs, weights, bias)
	local sum = bias
	sum = sum + (inputs.x1 * weights.x1)
	sum = sum + (inputs.x2 * weights.x2)
	return sum
end

--- 2. 활성화 함수만 적용합니다.
function TutorialMath.applyActivation(funcName, preActivationSum)
	local activationFunc = ActivationFunctions[funcName]
	return activationFunc(preActivationSum)
end

--// --- 역전파(Backpropagation) 계산 ---

--- 3. 오차(Error)를 계산합니다.
function TutorialMath.calculateError(output, target)
	return target - output
end

--- 4. 활성화 함수의 '미분값'을 계산합니다.
function TutorialMath.getActivationDerivative(funcName, output)
	if funcName == "Sigmoid" then
		-- Sigmoid의 미분: output * (1 - output)
		return output * (1 - output)
	elseif funcName == "ReLU" then
		return if output > 0 then 1 else 0
	end
	return 0
end

--- 5. 델타(Delta) 값을 계산합니다. (오차 * 미분값)
function TutorialMath.calculateDelta(error, activationDerivative)
	return error * activationDerivative
end

--- 6. 경사 하강법(Gradient Descent)을 위한 가중치/편향 변경량을 계산합니다.
function TutorialMath.calculateGradients(inputs, delta)
	local dw1 = delta * inputs.x1 -- 1번 가중치에 대한 '책임'
	local dw2 = delta * inputs.x2 -- 2번 가중치에 대한 '책임'
	local db = delta             -- 편향에 대한 '책임'
	return dw1, dw2, db
end

--- 7. [최종] 계산된 변경량으로 실제 가중치와 편향을 업데이트합니다.
function TutorialMath.applyUpdate(weights, bias, dw1, dw2, db)
	local newWeights = {
		x1 = weights.x1 + (LEARNING_RATE * dw1),
		x2 = weights.x2 + (LEARNING_RATE * dw2),
	}
	local newBias = bias + (LEARNING_RATE * db)
	return newWeights, newBias
end

return TutorialMath