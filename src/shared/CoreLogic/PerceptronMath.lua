local PerceptronMath = {}

--// 수학 상수 //--
local E = math.exp

--// 1. 활성화 함수 (Sigmoid) //--
function PerceptronMath.sigmoid(x)
	return 1 / (1 + E(-x))
end

--// 2. 활성화 함수의 도함수 (Sigmoid Derivative) //--
function PerceptronMath.sigmoidDerivative(output)
	return output * (1 - output)
end

--// 3. 내적 (Dot Product) + 편향(Bias) //--
function PerceptronMath.calculateSum(inputs, weights, bias)
	local sum = 0
	
	if #inputs ~= #weights then
		warn("PerceptronMath: 입력값과 가중치의 개수가 다릅니다!")
		return 0
	end

	for i = 1, #inputs do
		sum = sum + (inputs[i] * weights[i])
	end
	
	return sum + bias
end

--// [신규] 4. 출력 계산 (Calculate Output) //--
-- 내적 계산 후 활성화 함수를 적용하여 최종 출력과 합계(Sum)를 반환합니다.
function PerceptronMath.calculateOutput(inputs, weights, bias, activationFunc)
	local sum = PerceptronMath.calculateSum(inputs, weights, bias)
	local output = 0
	
	-- activationFunc가 함수(예: Sigmoid)로 전달되면 실행, 아니면 기본 Sigmoid 사용
	if type(activationFunc) == "function" then
		output = activationFunc(sum)
	else
		output = PerceptronMath.sigmoid(sum)
	end
	
	return output, sum
end

--// [신규] 5. 손실 계산 (Calculate Loss) //--
-- 평균 제곱 오차(MSE) 공식을 사용하여 손실값을 계산합니다.
-- Loss = 0.5 * (Target - Output)^2
function PerceptronMath.calculateLoss(output, target)
	return 0.5 * (target - output)^2
end

--// 6. 단순 오차 계산 (Calculate Error for Delta) //--
-- 역전파 델타 계산용 단순 차이
function PerceptronMath.calculateError(target, output)
	return target - output
end

--// 7. 델타 계산 (Calculate Delta) //--
function PerceptronMath.calculateDelta(error, output)
	return error * PerceptronMath.sigmoidDerivative(output)
end

--// 8. 가중치 업데이트 (Update Weights) //--
function PerceptronMath.updateWeights(weights, inputs, delta, learningRate)
	local newWeights = {}
	
	for i = 1, #weights do
		local change = delta * inputs[i] * learningRate
		newWeights[i] = weights[i] + change
	end
	
	return newWeights
end

--// 9. 편향 업데이트 (Update Bias) //--
function PerceptronMath.updateBias(bias, delta, learningRate)
	return bias + (delta * learningRate)
end

return PerceptronMath