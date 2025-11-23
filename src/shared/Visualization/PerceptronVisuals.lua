-- Shared/Visualization/PerceptronVisuals.lua
local PerceptronVisuals = {}
PerceptronVisuals.__index = PerceptronVisuals

function PerceptronVisuals.new(parts)
	local self = setmetatable({}, PerceptronVisuals)
	self.parts = parts -- {x1, x2, x3, Neuron, y}
	self.beams = {
		x1 = parts.container:FindFirstChild("Beam_x1"),
		x2 = parts.container:FindFirstChild("Beam_x2"),
		x3 = parts.container:FindFirstChild("Beam_x3"),
		Neuron = parts.container:FindFirstChild("Beam_Neuron")
	}
	return self
end

function PerceptronVisuals:updateInputs(inputValues)
	for key, value in pairs(inputValues) do
		if self.parts[key] then
			self.parts[key].Color = Color3.new(value, value, value)
		end
	end
end

function PerceptronVisuals:updateWeights(weightValues)
	for key, value in pairs(weightValues) do
		local beam = self.beams[key]
		if beam then
			local color
			if value >= 0 then
				color = Color3.new(0, 1, 0) -- Green for positive
			else
				color = Color3.new(1, 0, 0) -- Red for negative
			end
			beam.Color = ColorSequence.new(color)
			beam.Transparency = NumberSequence.new(1 - math.abs(value) * 0.9)
			beam.LightEmission = math.abs(value) * 0.8
		end
	end
end

function PerceptronVisuals:updateBias(biasValue)
	-- Bias를 -1~1 범위에서 밝기 0~1 범위로 변환
	local brightness = (biasValue + 1) / 2
	self.parts.Neuron.Color = Color3.fromHSV(0.6, 0.8, brightness) -- Blue hue, brightness changes
end

function PerceptronVisuals:updateOutput(outputValue)
	-- Output을 0~1 범위로 클램프하여 밝기 조절
	local brightness = math.clamp(outputValue, 0, 1)
	self.parts.y.Color = Color3.new(brightness, brightness, brightness)
end

return PerceptronVisuals