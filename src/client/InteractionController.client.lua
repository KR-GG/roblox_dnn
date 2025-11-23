-- StarterPlayerScripts/InteractionController.lua

--// 서비스 및 객체 불러오기 //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MapService = require(ReplicatedStorage.Shared.Services.MapService)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// ========================================================== //--
--//        UI 및 콘텐츠 설정 (여기에 새 디스플레이를 추가하세요)       //--
--// ========================================================== //--

-- 각 디스플레이 모델의 이름과 연결할 ScreenGui, 페이지 콘텐츠를 짝지어줍니다.
local PROMPT_CONFIG = {
	["Display1"] = {
		gui = playerGui:WaitForChild("NeuronInfoUI"),
		pages = {
			{
				title = "1. The Blueprint: The Artificial Neuron",
				content = "Before you stands the fundamental building block of all artificial intelligence. This is not just a model; it is the <b>blueprint</b> for a new form of thought.\n\nLike its biological counterpart, this <font color='#FFFF64'>Artificial Neuron</font> performs one elegant function: it aggregates signals from multiple inputs. If the combined strength of these signals crosses a critical <b>activation threshold</b>, it fires."
			},
			{
				title = "2. The Principle: Learning through Weights",
				content = "A neuron's potential is unlocked through learning. For an AI, 'learning' is the process of adjusting the importance of its inputs. This is achieved through <font color='#FFFF64'>Weights</font>.\n\nAn AI learns by automatically tuning millions of connections until the desired output is achieved. This simple principle transforms a basic on/off switch into a nuanced decision-maker."
			},
			{
				title = "3. The Architecture of Complexity",
				content = "If the neuron before you is a single brick, then a <b>Deep Neural Network (DNN)</b> is the skyscraper.\n\nBy arranging these simple neurons into vast, interconnected layers, something remarkable emerges: <b>complexity</b>. This is the power of <font color='#FFFF64'>Architecture</font>.\n\nNow, you are the architect. It is time to build."
			}
		}
	},
	["Display2"] = {
		gui = playerGui:WaitForChild("PerceptronLabUI"),
		pages = {
			{
				title = "1. The Perceptron Lab",
				content = "Welcome to the Perceptron Lab. The model before you is a simple artificial neuron with <b>3 inputs</b> and <b>1 output</b>.\n\nYou have full control over its internal parameters. Your challenge: can you configure it to solve a problem?"
			},
			{
				title = "2. Tuning the Connections: Weights",
				content = "The sliders labeled <b>w1, w2,</b> and <b>w3</b> control the <font color='#FFFF64'>Weights</font> for each of the three inputs.\n\nA weight determines how influential an input is. A high positive weight amplifies an input's signal, while a negative weight can reverse its effect."
			},
			{
				title = "3. Setting the Threshold: The Bias",
				content = "The <b>Bias</b> slider adds a constant value <b>after</b> the inputs have been weighted.\n\nThink of it as a 'head start' or a 'handicap'. A positive bias makes the neuron <font color='#FFFF64'>easier to activate</font>, while a negative bias makes it <font color='#FFFF64'>harder</font>."
			},
			{
				title = "4. The Decision: Activation Function",
				content = "The <b>Activation Function</b> takes the final calculated value and makes the final decision.\n\nYou can cycle through different types:\n• <b>Step:</b> A simple ON/OFF switch.\n• <b>Sigmoid/Tanh:</b> Smooth functions for nuanced outputs.\n• <b>ReLU:</b> An efficient function that only passes positive signals."
			}
		}
	},
	--["Display3"] = { -- 순전파/역전파 설명 패널
	--	gui = playerGui:WaitForChild("PropagationInfoUI"), -- 새로 만든 GUI 이름
	--	pages = {
	--		{
	--			title = "1. Forward Propagation: The Prediction",
	--			content = "How does the network make a prediction? Through <b>Forward Propagation</b>.\n\nInput data travels layer by layer, transformed by <font color='#FFFF64'>Weights</font>, <font color='#FFFF64'>Biases</font>, and <font color='#FFFF64'>Activation Functions</font> until it produces the final prediction."
	--		},
	--		{
	--			title = "2. Calculating the Error: The Reality Check",
	--			content = "The network made its prediction. Now, we compare it to the actual correct answer to calculate the <font color='#FFFF64'>Error</font> (or Loss).\n\nThis error value tells the network *how much* it needs to adjust its parameters."
	--		},
	--		{
	--			title = "3. Backpropagation: Assigning Blame",
	--			content = "This is the core of learning: <font color='#FFFF64'>Backpropagation</font>. The error signal flows backward through the network.\n\nCalculus is used to determine how much each <b>Weight</b> and <b>Bias</b> contributed to the overall error."
	--		},
	--		{
	--			title = "4. Gradient Descent: Making Adjustments",
	--			content = "Based on the 'blame' assigned by backpropagation, <font color='#FFFF64'>Gradient Descent</font> makes tiny adjustments to each Weight and Bias.\n\nThis cycle of <b>Forward → Error → Backward → Adjust</b> repeats, allowing the network to gradually minimize its errors. This is <b>learning</b>."
	--		}
	--	}
	--},
	["Display4"] = { -- 네트워크 생성 정보 패널
		gui = playerGui:WaitForChild("NetworkCreateInfoUI"), -- 새로 만든 GUI 이름
		pages = {
			{
				title = "1. The Task: Choosing the Dataset",
				content = "Every neural network is trained for a specific task. The <b>Dataset</b> you select determines that task and shapes the network's required input and output layers.\n\n• <b>XOR:</b> A classic logic problem.\n• <b>IRIS:</b> Classifying flower species.\n• <b>MNIST:</b> Recognizing handwritten digits.\n• <b>PRICE:</b> Predicting housing prices."
			},
			{
				title = "2. The Core: Depth & Neurons",
				content = "The 'thinking' part happens in the <font color='#FFFF64'>Hidden Layers</font>.\n\n• <b>Depth:</b> More layers = more complexity.\n• <b>Neurons per Layer:</b> More neurons = more processing power.\n\nExperimentation is key to finding the right <font color='#FFFF64'>Architecture</font>."
			},
			{
				title = "3. The Switch: Activation Function",
				content = "The <b>Activation Function</b> decides if a neuron 'fires'. This choice significantly impacts learning.\n\n• <b>Sigmoid/Tanh:</b> Smooth curves.\n• <b>ReLU:</b> Fast and efficient.\n• <b>Step:</b> Simple ON/OFF.\n\nReady to build? Select your configuration and press 'Create Network'."
			}
		}
	}
}


--// ========================================================== //--
--//           UI 제어 로직 (이 아래는 수정할 필요 없음)          //--
--// ========================================================== //--

-- UI 페이지를 업데이트하고 버튼 이벤트를 연결하는 범용 함수
local function setupGuiControls(gui, pages)
	local mainFrame = gui.MainFrame
	local titleLabel = mainFrame.TitleLabel
	local contentLabel = mainFrame.ContentLabel
	local prevButton = mainFrame.PreviousButton
	local nextButton = mainFrame.NextButton
	local pageIndicator = mainFrame.PageIndicator
	local closeButton = mainFrame.CloseButton

	local currentPage = 1

	local function updatePage()
		currentPage = math.clamp(currentPage, 1, #pages)
		local pageData = pages[currentPage]

		titleLabel.Text = pageData.title
		contentLabel.Text = pageData.content
		pageIndicator.Text = string.format("%d / %d", currentPage, #pages)

		prevButton.Visible = (currentPage > 1)
		if currentPage == #pages then nextButton.Text = "Close" else nextButton.Text = "Next >" end
	end

	prevButton.MouseButton1Click:Connect(function() currentPage = currentPage - 1; updatePage() end)
	nextButton.MouseButton1Click:Connect(function() if currentPage == #pages then gui.Enabled = false else currentPage = currentPage + 1; updatePage() end end)
	closeButton.MouseButton1Click:Connect(function() gui.Enabled = false end)

	-- 함수를 반환하여 ProximityPrompt에서 호출할 수 있도록 함
	return updatePage
end

--// 모든 준비가 완료된 후 실행될 메인 초기화 함수 //--
local function Initialize()
	print("InteractionController: ClientReady 신호를 받았습니다. 모든 ProximityPrompt 설정을 시작합니다.")

	local currentMap = MapService.getCurrentMap()
	if not currentMap then
		warn("InteractionController 초기화 실패: 현재 맵을 찾을 수 없습니다.")
		return
	end

	-- PROMPT_CONFIG에 정의된 모든 디스플레이에 대해 설정 함수 실행
	for displayName, config in pairs(PROMPT_CONFIG) do
		local displayModel = currentMap:FindFirstChild(displayName, true)
		if displayModel then
			print("Model found")
			local interactionPart = displayModel:WaitForChild("Display", 5)
			if interactionPart then
				print("Display found")
				local prompt = interactionPart:WaitForChild("ProximityPrompt", 5)
				if prompt then
					print("Prompt found")
					local updatePageFunction = setupGuiControls(config.gui, config.pages)

					prompt.Triggered:Connect(function()
						config.gui.Enabled = not config.gui.Enabled
						if config.gui.Enabled then
							updatePageFunction() -- UI가 켜질 때 항상 첫 페이지(또는 현재 페이지)를 다시 그림
						end
					end)
					print(string.format("InteractionController: '%s'의 ProximityPrompt에 성공적으로 연결했습니다.", displayName))
				end
			end
		end
	end

	-- 모든 UI를 처음에는 숨김
	for _, config in pairs(PROMPT_CONFIG) do
		config.gui.Enabled = false
	end
end

Initialize()

print("InteractionController: 모든 UI 제어 기능이 준비되었습니다.")