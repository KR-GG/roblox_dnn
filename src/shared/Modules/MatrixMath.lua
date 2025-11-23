--[[
    TutorialMath.lua
    'Matrix Lab'의 2-2-1 네트워크 튜토리얼 전용 계산 모듈.
    퀴즈를 위해 순전파/역전파 계산을 단계별로 세분화합니다.
--]]
local MatrixMath = {}

local ActivationFunctions = require(game:GetService("ReplicatedStorage").Shared.CoreLogic.ActivationFunctions)
local LEARNING_RATE = 0.1

--// --- 순전파(Forward Pass) 계산 ---

--- 1. 은닉층(Hidden Layer)의 가중합(Weighted Sum)을 계산합니다.
function MatrixMath.calculateHiddenLayerSum(inputs, weights_h, biases_h)
	local sum_h1 = (inputs.x1 * weights_h.w1_h1) + (inputs.x2 * weights_h.w2_h1) + biases_h.b1
	local sum_h2 = (inputs.x1 * weights_h.w1_h2) + (inputs.x2 * weights_h.w2_h2) + biases_h.b2
	return {h1 = sum_h1, h2 = sum_h2}
end

--- 2. 은닉층에 활성화 함수를 적용합니다. (여러 값)
function MatrixMath.applyHiddenActivation(funcName, sums_h)
	local activationFunc = ActivationFunctions[funcName]
	local act_h1 = activationFunc(sums_h.h1)
	local act_h2 = activationFunc(sums_h.h2)
	return {h1 = act_h1, h2 = act_h2}
end

--- 3. 출력층(Output Layer)의 가중합을 계산합니다.
function MatrixMath.calculateOutputSum(hidden_activations, weights_o, bias_o)
	local sum_o = (hidden_activations.h1 * weights_o.w_h1_o) + (hidden_activations.h2 * weights_o.w_h2_o) + bias_o.b
	return sum_o
end

--- 4. [신규 추가!] 단일 값에 활성화 함수를 적용합니다. (출력층용)
function MatrixMath.applyActivation(funcName, preActivationSum)
	local activationFunc = ActivationFunctions[funcName]
	if not activationFunc then
		warn("MatrixMath Error: Unknown activation function " .. tostring(funcName))
		return 0
	end
	return activationFunc(preActivationSum)
end


--// --- 역전파(Backpropagation) 계산 ---

--- 5. 오차(Error) 계산
function MatrixMath.calculateError(output, target) return target - output end

--- 6. 미분(Derivative) 계산
function MatrixMath.getActivationDerivative(funcName, output)
	if funcName == "Sigmoid" then return output * (1 - output) end
	if funcName == "ReLU" then return if output > 0 then 1 else 0 end
	return 0
end

--- 7. 델타(Delta) 계산
function MatrixMath.calculateDelta(error, activationDerivative) return error * activationDerivative end

--- 8. 경사 하강법 변경량 계산
function MatrixMath.calculateGradients(inputs, delta)
	local dw1 = delta * inputs.x1
	local dw2 = delta * inputs.x2
	local db = delta
	return dw1, dw2, db
end

--- 9. [최종] 경사 하강법으로 모든 가중치와 편향을 업데이트합니다.
function MatrixMath.applyFullUpdate(state, delta)
	local inputs = state.inputs
	local hidden_acts = state.lastHiddenActivations
	local weights_h = state.weights_h
	local biases_h = state.biases_h
	local weights_o = state.weights_o
	local bias_o = state.bias_o

	-- 출력층 업데이트
	local dw_h1_o = delta * hidden_acts.h1
	local dw_h2_o = delta * hidden_acts.h2
	local db_o = delta

	weights_o.w_h1_o = weights_o.w_h1_o + (LEARNING_RATE * dw_h1_o)
	weights_o.w_h2_o = weights_o.w_h2_o + (LEARNING_RATE * dw_h2_o)
	bias_o.b = bias_o.b + (LEARNING_RATE * db_o)

	-- 은닉층 업데이트 (간략화된 버전)
	local delta_h1 = delta * weights_h.w1_h1
	local delta_h2 = delta * weights_h.w1_h2

	local dw1_h1 = delta_h1 * inputs.x1
	local dw1_h2 = delta_h2 * inputs.x1
	local dw2_h1 = delta_h1 * inputs.x2
	local dw2_h2 = delta_h2 * inputs.x2
	local db1 = delta_h1
	local db2 = delta_h2

	weights_h.w1_h1 = weights_h.w1_h1 + (LEARNING_RATE * dw1_h1)
	weights_h.w1_h2 = weights_h.w1_h2 + (LEARNING_RATE * dw1_h2)
	weights_h.w2_h1 = weights_h.w2_h1 + (LEARNING_RATE * dw2_h1)
	weights_h.w2_h2 = weights_h.w2_h2 + (LEARNING_RATE * dw2_h2)
	biases_h.b1 = biases_h.b1 + (LEARNING_RATE * db1)
	biases_h.b2 = biases_h.b2 + (LEARNING_RATE * db2)

	return weights_h, biases_h, weights_o, bias_o
end

return MatrixMath