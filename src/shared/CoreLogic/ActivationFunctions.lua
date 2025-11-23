-- shared/CoreLogic/ActivationFunctions.lua
local Functions = {}

function Functions.Sigmoid(x)
	return 1 / (1 + math.exp(-x))
end

function Functions.Tanh(x)
	return math.tanh(x)
end

function Functions.ReLU(x)
	return math.max(0, x)
end

function Functions.Step(x)
    if x >= 0 then
        return 1
    else
        return 0
    end
end

return Functions