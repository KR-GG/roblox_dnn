-- Shared/UI/UIManager.lua
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local UIManager = {}
UIManager.__index = UIManager

function UIManager.new(gui)
	local self = setmetatable({}, UIManager)
	self.gui = gui
	self.sliders = {
		w1 = gui.MainFrame.SliderW1,
		w2 = gui.MainFrame.SliderW2,
        w3 = gui.MainFrame.SliderW3,
		bias = gui.MainFrame.SliderBias
	}
	self.activationButton = gui.MainFrame.ActivationButton
	self.lossLabel = gui.MainFrame.LossLabel

	self.ParameterChanged = Instance.new("BindableEvent")
    self.ActivationChanged = Instance.new("BindableEvent")

	self:_setupAllSliders(self.sliders)
	self:_setupActivationButton()

	return self
end

function UIManager:_setupSlider(sliderName, sliderFrame, eventToFire)
    local handle = sliderFrame.Handle
    local isDragging = false

    handle.MouseButton1Down:Connect(function()
        isDragging = true
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local frameWidth = sliderFrame.AbsoluteSize.X
            local relativeX = (input.Position.X - sliderFrame.AbsolutePosition.X) / frameWidth
            relativeX = math.clamp(relativeX, 0, 1)

            handle.Position = UDim2.fromScale(relativeX, 0)
            
            -- Convert value to -1 to 1 range
            local value = (relativeX * 2) - 1
            
            -- Fire the event with BOTH the name and the value
            eventToFire:Fire(sliderName, value)
        end
    end)
end

function UIManager:_setupAllSliders(sliders)
    for name, slider in pairs(sliders) do
        -- No need to check for different types, just pass the name and use the single event
        self:_setupSlider(name, slider, self.ParameterChanged)
    end
end

function UIManager:_setupActivationButton()
	self.activationButton.MouseButton1Click:Connect(function()
		self.ActivationChanged:Fire()
	end)
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

function UIManager:updateUIState(state)
	for key, value in pairs(state) do
        if key == "w1" and self.sliders.w1 then
            self.sliders.w1.Handle.Position = UDim2.fromScale((value + 1) / 2, 0)
            self.sliders.w1.Title.Text = string.format("W1: %.2f", value)
        elseif key == "w2" and self.sliders.w2 then
            self.sliders.w2.Handle.Position = UDim2.fromScale((value + 1) / 2, 0)
            self.sliders.w2.Title.Text = string.format("W2: %.2f", value)
        elseif key == "w3" and self.sliders.w3 then
            self.sliders.w3.Handle.Position = UDim2.fromScale((value + 1) / 2, 0)
            self.sliders.w3.Title.Text = string.format("W3: %.2f", value)
        elseif key == "bias" and self.sliders.bias then
            self.sliders.bias.Handle.Position = UDim2.fromScale((value + 1) / 2, 0)
            self.sliders.bias.Title.Text = string.format("Bias: %.2f", value)
        elseif key == "activationName" and self.activationButton then
            self.activationButton.Text = "Activation: " .. value
        elseif key == "loss" and self.lossLabel then
            self.lossLabel.Text = string.format("Loss: %.4f", value)
        end
    end
end

return UIManager