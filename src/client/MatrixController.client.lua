-- MatrixController.lua

--// 서비스 및 모듈 불러오기 //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatrixMath = require(ReplicatedStorage.Shared.Modules.MatrixMath)
local MatrixVisualizer = require(ReplicatedStorage.Shared.Visualization.MatrixVisualizer)
local ActivationFunctions = require(ReplicatedStorage.Shared.CoreLogic.ActivationFunctions)
local MapService = require(ReplicatedStorage.Shared.Services.MapService)

--// 변수 선언 //--
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 2-2-1 네트워크 튜토리얼을 위한 state
local state = {
	inputs = { x1 = 1, x2 = 0 }, -- XOR [1, 0] 테스트
	weights_h = { w1_h1 = 0.5, w1_h2 = -0.4, w2_h1 = 0.8, w2_h2 = 0.1 },
	biases_h = { b1 = 0.1, b2 = -0.2 },
	weights_o = { w_h1_o = 0.7, w_h2_o = -0.3 },
	bias_o = { b = 0.05 },
	target = 1, activationName = "Sigmoid", trainingStep = 1, quizAttempts = 0,
	currentQuizAnswer = nil, currentQuizExplanation = nil,
	lastHiddenSums = {h1 = 0, h2 = 0}, lastHiddenActivations = {h1 = 0, h2 = 0},
	lastOutputSum = 0, lastOutput = 0, lastError = 0, lastDelta = 0
}

-- [수정] GUI 및 모듈 인스턴스 변수 (지역 변수로 선언)
local workspaceParts = {}
local tutorialGui, pg_title, pg_content, pg_prev, pg_next, pg_page, pg_close, pg_status
local q_frame, q_question, q_option1, q_option2, q_option3, q_feedback
local visuals = {} -- [수정] visuals를 nil이 아닌 빈 테이블로 선언

-- [수정] COLOR_DEFAULT 값 추가
local COLOR_DEFAULT = Color3.fromRGB(150, 150, 150)

-- [신규] 튜토리얼 단계 (행렬곱)
local TUTORIAL_STEPS = {
	[1] = { title = "Step 1: The Problem of Scale", content = "Welcome. Our old neuron was simple. But to solve complex problems like <b>XOR</b>, we need more neurons, creating <b>Layers</b>.\n\nThis is a <b>2-2-1</b> network. Click <b>[Next]</b>.", buttonText = "Next" },
	[2] = { title = "Step 2: The Inefficient Way", content = "To get the hidden layer values, we would have to run a Forward Pass for <b>h1</b>... \n...and *another* pass for <b>h2</b>.\n\nThis is slow. There is a better way. Click <b>[Next]</b>.", buttonText = "Next" },
	[3] = { title = "Step 3: Matrix Multiplication", content = "We can bundle all inputs, weights, and biases into <b>Matrices</b> (grids of numbers) and solve the *entire layer* in one operation.\n\n<b>[Inputs] * [Weights] + [Biases] = [Results]</b>", buttonText = "Run Forward Pass" },
	[4] = { title = "Step 4: Hidden Layer Sum", content = "The input `[%.1f, %.1f]` was multiplied by the weight matrix. The results are:\n\nSum <b>h1</b> = <b>%.2f</b>\nSum <b>h2</b> = <b>%.2f</b>\n\nClick <b>[Apply Activation]</b>.", buttonText = "Apply Activation" },
	[5] = { title = "Step 5: Hidden Layer Activation", content = "The Sigmoid function was applied to both sums:\n\nActivation <b>h1</b> = <b>%.2f</b>\nActivation <b>h2</b> = <b>%.2f</b>\n\nThese are the new inputs for the next layer. Click <b>[Calculate Output]</b>.", buttonText = "Calculate Output" },
	[6] = { title = "Step 6: Final Prediction", content = "The hidden activations (`[%.2f, %.2f]`) were processed by the output layer.\n\nFinal Prediction: <b>%.2f</b> | Target: <b>1.0</b>\n\nClick <b>[Calculate Error]</b>.", buttonText = "Calculate Error" },
	[7] = { title = "Step 7: Backpropagation", content = "The error is <b>%.2f</b>. This error is now sent <b>Backwards</b> through the *entire matrix* to update all connections at once.\n\nClick <b>[Run Backpropagation]</b>.", buttonText = "Run Backpropagation" },
	[8] = { title = "Step 8: Epochs", content = "That was <b>one</b> training step. It's not enough.\nAn <b>Epoch</b> is one full training cycle on the *entire* dataset. We repeat this thousands of times.\n\nClick <b>[Run 10 Epochs]</b> to simulate this.", buttonText = "Run 10 Epochs" },
	[9] = { title = "Step 9: Free Experiment", content = "Training complete! The network is now smarter. Click the <b>Input Blocks</b> to test new values `[0,0]`, `[0,1]`, `[1,1]` and see the results.", buttonText = "Run Forward Pass" },
}

-- [신규] 퀴즈 데이터베이스 (행렬)
local QUIZ_DATA = {
	["what_is_matrix"] = {
		getQuestion = function() return "QUIZ: What is the main advantage of using <b>Matrix Operations</b> here?" end,
		getOptions = function() return {
			opt1 = "It's more complex, so it's smarter.",
			opt2 = "It allows for massive parallel processing (GPU).",
			opt3 = "It only works for Sigmoid.",
			answer = "It allows for massive parallel processing (GPU).",
			explanation = "<b>Answer: Parallel Processing</b>. Matrices allow modern GPUs to perform thousands of calculations simultaneously, making it possible to train massive networks."
			} end
	},
	["epoch"] = {
		getQuestion = function() return "QUIZ: What is an <b>Epoch</b>?" end,
		getOptions = function() return {
			opt1 = "A single forward pass.",
			opt2 = "One full training cycle on the entire dataset.",
			opt3 = "The name of the error signal.",
			answer = "One full training cycle on the entire dataset.",
			explanation = "<b>Answer: A full training cycle</b>. One epoch = one pass over all the training data (e.g., all 60,000 MNIST images)."
			} end
	}
}

--// 함수 정의 //--

--- 모든 시각화(파트 색상, 빔, SurfaceGUI)를 현재 state 기준으로 업데이트
local function updateVisuals()
	-- 2-2-1 네트워크 순전파
	local sums_h = MatrixMath.calculateHiddenLayerSum(state.inputs, state.weights_h, state.biases_h)
	local acts_h = MatrixMath.applyHiddenActivation(state.activationName, sums_h)
	local sum_o = MatrixMath.calculateOutputSum(acts_h, state.weights_o, state.bias_o)
	local output = MatrixMath.applyActivation(state.activationName, sum_o)

	state.lastHiddenSums = sums_h
	state.lastHiddenActivations = acts_h
	state.lastOutputSum = sum_o
	state.lastOutput = output

	-- SurfaceGUI 업데이트
	local function getTextColor(value) return if value > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255) end
	if workspaceParts.x1 then workspaceParts.x1.SurfaceGui.TextLabel.Text = state.inputs.x1; workspaceParts.x1.SurfaceGui.TextLabel.TextColor3 = getTextColor(state.inputs.x1);workspaceParts.x1:WaitForChild("BillboardGui").WeightLabel.Text = string.format("%.2f\n\n%.2f", state.weights_h.w1_h2, state.weights_h.w1_h1) end
	if workspaceParts.x2 then workspaceParts.x2.SurfaceGui.TextLabel.Text = state.inputs.x2; workspaceParts.x2.SurfaceGui.TextLabel.TextColor3 = getTextColor(state.inputs.x2);workspaceParts.x2:WaitForChild("BillboardGui").WeightLabel.Text = string.format("%.2f\n\n%.2f", state.weights_h.w2_h2, state.weights_h.w2_h1) end
	if workspaceParts.h1 then workspaceParts.h1.CalculationDisplay.TextLabel.Text = ""; workspaceParts.h1.Color = COLOR_DEFAULT; workspaceParts.h1:WaitForChild("BillboardGui").WeightLabel.Text = string.format("%.2f", state.weights_o.w_h1_o) end
	if workspaceParts.h2 then workspaceParts.h2.CalculationDisplay.TextLabel.Text = ""; workspaceParts.h2.Color = COLOR_DEFAULT; workspaceParts.h2:WaitForChild("BillboardGui").WeightLabel.Text = string.format("%.2f", state.weights_o.w_h2_o) end

	-- [신규] 빔(가중치) 텍스트 및 색상 업데이트 (2-2-1)
	local function updateBeam(part, beamName, weight)
		if not part then return end
		local beam = part:FindFirstChild(beamName)
		if not beam then return end
		beam.Color = if weight >= 0 then ColorSequence.new(Color3.new(0,1,0)) else ColorSequence.new(Color3.new(1,0,0))
		local labelGui = beam:FindFirstChildOfClass("BillboardGui")
		if labelGui then labelGui:FindFirstChildOfClass("TextLabel").Text = string.format("%.2f", weight) end
	end
	-- 은닉층 빔
	updateBeam(workspaceParts.x1, "Beam_x1_h1", state.weights_h.w1_h1)
	updateBeam(workspaceParts.x1, "Beam_x1_h2", state.weights_h.w1_h2)
	updateBeam(workspaceParts.x2, "Beam_x2_h1", state.weights_h.w2_h1)
	updateBeam(workspaceParts.x2, "Beam_x2_h2", state.weights_h.w2_h2)
	-- 출력층 빔
	updateBeam(workspaceParts.h1, "Beam_h1_y", state.weights_o.w_h1_o)
	updateBeam(workspaceParts.h2, "Beam_h2_y", state.weights_o.w_h2_o)
end

--- 튜토리얼 UI 페이지 업데이트
local function updateTutorialUI(step)
	state.trainingStep = step
	local pageData = TUTORIAL_STEPS[state.trainingStep]
	if not pageData then return end

	local content = pageData.content
	if state.trainingStep == 4 then content = string.format(pageData.content, state.inputs.x1, state.inputs.x2, state.lastHiddenSums.h1, state.lastHiddenSums.h2)
	elseif state.trainingStep == 5 then content = string.format(pageData.content, state.lastHiddenActivations.h1, state.lastHiddenActivations.h2)
	elseif state.trainingStep == 6 then content = string.format(pageData.content, state.lastHiddenActivations.h1, state.lastHiddenActivations.h2, state.lastOutput)
	elseif state.trainingStep == 7 then
		state.lastError = MatrixMath.calculateError(state.lastOutput, state.target)
		content = string.format(pageData.content, state.lastError) 
	end

	pg_title.Text = pageData.title; pg_content.Text = content
	pg_page.Text = string.format("Step %d / %d", state.trainingStep, #TUTORIAL_STEPS); pg_next.Text = pageData.buttonText
	pg_prev.Visible = (state.trainingStep > 1); q_frame.Visible = false; pg_next.Visible = true
	if pg_status then pg_status.Visible = false end 
end

--- 퀴즈 UI 표시 (nil 값 안전 처리)
local function showQuiz(quizID, dynamicValue)
	local quiz = QUIZ_DATA[quizID]
	if not quiz then return end
	local question = quiz.getQuestion(dynamicValue)
	local options = quiz.getOptions(dynamicValue)
	q_question.Text = question; q_option1.Text = options.opt1 or ""; q_option2.Text = options.opt2 or ""; q_option3.Text = options.opt3 or ""
	q_feedback.Text = ""; state.currentQuizAnswer = options.answer; state.currentQuizExplanation = options.explanation
	state.quizAttempts = 0
	q_option1.Visible = (options.opt1 ~= nil); q_option2.Visible = (options.opt2 ~= nil); q_option3.Visible = (options.opt3 ~= nil)
	pg_next.Visible = false; q_frame.Visible = true
end

--- 퀴즈 정답 처리 (2단계 기회)
local function onQuizAnswer(selectedAnswer)
	if selectedAnswer == state.currentQuizAnswer then
		q_feedback.Text = "Correct! Advancing to the next step..."
		q_feedback.TextColor3 = Color3.fromRGB(0, 255, 0); task.wait(1.5)
		if state.trainingStep == 3.5 then updateTutorialUI(4)
		elseif state.trainingStep == 8.5 then updateTutorialUI(9)
		end
	else
		state.quizAttempts = state.quizAttempts + 1
		if state.quizAttempts == 1 then
			q_feedback.Text = "Not quite. Think about the concept and try again!"
			q_feedback.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			q_feedback.Text = state.currentQuizExplanation
			q_feedback.TextColor3 = Color3.fromRGB(255, 200, 0); task.wait(4)
			if state.trainingStep == 3.5 then updateTutorialUI(4)
			elseif state.trainingStep == 8.5 then updateTutorialUI(9)
			end
		end
	end
end

--- 튜토리얼 단계 실행 (Next 버튼)
local function onNextStepClicked()
	if q_frame.Visible or (pg_status and pg_status.Visible) then return end -- [수정] 애니메이션 중 중복 클릭 방지

	local step = state.trainingStep
	if step == 1 then updateTutorialUI(2)
	elseif step == 2 then updateTutorialUI(3)
	elseif step == 3 then -- [Run Forward Pass]
		updateVisuals()
		pg_status.Visible = true
		MatrixVisualizer.playForwardPass(workspaceParts, state.inputs)
		task.wait(1.5)
		pg_status.Visible = false
		state.trainingStep = 3.5
		showQuiz("what_is_matrix", nil)
	elseif step == 4 then -- [Apply Activation]
		pg_status.Visible = true
		local h1_calc_string = string.format("(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f",
			state.inputs.x1, state.weights_h.w1_h1,
			state.inputs.x2, state.weights_h.w2_h1,
			state.biases_h.b1,
			state.lastHiddenSums.h1)
		local h2_calc_string = string.format("(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f",
			state.inputs.x1, state.weights_h.w1_h2,
			state.inputs.x2, state.weights_h.w2_h2,
			state.biases_h.b2,
			state.lastHiddenSums.h2)

		MatrixVisualizer.showCalculationText(workspaceParts.h1, h1_calc_string, 4)
		MatrixVisualizer.showCalculationText(workspaceParts.h2, h2_calc_string, 4)
		task.wait(4.2)
		pg_status.Visible = false
		updateTutorialUI(5)
	elseif step == 5 then -- [Calculate Output]
		pg_status.Visible = true
		MatrixVisualizer.playHiddenActivation(workspaceParts, state.lastHiddenActivations)
		task.wait(2.2)
		local sum_o = MatrixMath.calculateOutputSum(state.lastHiddenActivations, state.weights_o, state.bias_o)
		local output = MatrixMath.applyActivation(state.activationName, sum_o)
		state.lastOutput = output; state.lastOutputSum = sum_o
		MatrixVisualizer.playOutputPass(workspaceParts, state.lastHiddenActivations)
		task.wait(1.2)
		MatrixVisualizer.showCalculationText(workspaceParts.y, string.format("(%.2f*%.2f)+(%.2f*%.2f)+%.2f=%.2f", state.lastHiddenActivations.h1, state.weights_o.w_h1_o, state.lastHiddenActivations.h2, state.weights_o.w_h2_o, state.bias_o.b, sum_o), 3)
		task.wait(3.2)
		MatrixVisualizer.playActivation(workspaceParts.y, output, workspaceParts.y)
		pg_status.Visible = false
		updateVisuals()
		updateTutorialUI(6)
	elseif step == 6 then -- [Calculate Error]
		updateTutorialUI(7)
	elseif step == 7 then -- [Run Backpropagation]
		pg_status.Visible = true
		MatrixVisualizer.playBackwardPass(workspaceParts) -- 이 함수가 내부적으로 yield한다고 가정
		pg_status.Visible = false
		updateTutorialUI(8)
	elseif step == 8 then -- [Run 10 Epochs]
		local delta = MatrixMath.calculateDelta(state.lastError, MatrixMath.getActivationDerivative(state.activationName, state.lastOutput))
		pg_status.Visible = true
		MatrixVisualizer.playEpochLoop(workspaceParts) -- 이 함수가 내부적으로 yield한다고 가정
		for i = 1, 10 do
			local w_h, b_h, w_o, b_o = MatrixMath.applyFullUpdate(state, delta)
			state.weights_h = w_h; state.biases_h = b_h; state.weights_o = w_o; state.bias_o = b_o
			updateVisuals()
			delta = MatrixMath.calculateDelta(MatrixMath.calculateError(state.lastOutput, state.target), MatrixMath.getActivationDerivative(state.activationName, state.lastOutput))
			task.wait(0.05) -- 루프가 너무 빠르지 않게 약간의 대기
		end
		state.trainingStep = 8.5
		task.wait(1.5) -- 퀴즈 전 대기
		pg_status.Visible = false
		showQuiz("epoch", nil)
	elseif step == 9 or step == 10 then -- [Run Forward Pass Again]
		pg_status.Visible = true
		updateVisuals()
		MatrixVisualizer.playForwardPass(workspaceParts, state.inputs)
		task.wait(1.2)

		local h1_calc_string = string.format("(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f",
			state.inputs.x1, state.weights_h.w1_h1,
			state.inputs.x2, state.weights_h.w2_h1,
			state.biases_h.b1,
			state.lastHiddenSums.h1)
		local h2_calc_string = string.format("(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f",
			state.inputs.x1, state.weights_h.w1_h2,
			state.inputs.x2, state.weights_h.w2_h2,
			state.biases_h.b2,
			state.lastHiddenSums.h2)

		MatrixVisualizer.showCalculationText(workspaceParts.h1, h1_calc_string, 4)
		MatrixVisualizer.showCalculationText(workspaceParts.h2, h2_calc_string, 4)

		task.wait(4.2)

		MatrixVisualizer.playHiddenActivation(workspaceParts, state.lastHiddenActivations)
		task.wait(2.2)
		local sum_o = MatrixMath.calculateOutputSum(state.lastHiddenActivations, state.weights_o, state.bias_o)
		local output = MatrixMath.applyActivation(state.activationName, sum_o)
		state.lastOutput = output; state.lastOutputSum = sum_o
		MatrixVisualizer.playOutputPass(workspaceParts, state.lastHiddenActivations)
		task.wait(1.2)
		MatrixVisualizer.showCalculationText(workspaceParts.y, string.format("Sum = %.2f", sum_o), 3)
		task.wait(3.2)
		MatrixVisualizer.playActivation(workspaceParts.y, output, workspaceParts.y)
		pg_status.Visible = false
		updateVisuals()
		updateTutorialUI(10)
	end
end

--- 입력 파트 클릭 (10단계에서만 활성화)
local function onInputPartClicked(partName)
	if q_frame.Visible or (pg_status and pg_status.Visible) then return end
	if state.trainingStep < 10 then
		q_feedback.Text = "Free experimentation is unlocked at Step 10. Please complete the tutorial first."
		q_frame.Visible = true; pg_next.Visible = false; task.wait(2)
		q_frame.Visible = false; pg_next.Visible = true
		return 
	end
	if state.inputs[partName] == 0 then state.inputs[partName] = 1 else state.inputs[partName] = 0 end
	updateVisuals()
end

--// 메인 초기화 함수 //--
local function Initialize()
	print("MatrixController: ClientReady 신호를 받았습니다. 초기화를 시작합니다.")

	local currentMap = MapService.getCurrentMap()
	if not currentMap then error("MatrixController 초기화 실패: 현재 맵을 찾을 수 없습니다.") return end
	local tutorialModel = currentMap:WaitForChild("MatrixPerceptron")

	workspaceParts = { container = tutorialModel, x1 = tutorialModel:WaitForChild("x1"), x2 = tutorialModel:WaitForChild("x2"), h1 = tutorialModel:WaitForChild("h1"), h2 = tutorialModel:WaitForChild("h2"), y = tutorialModel:WaitForChild("y") }

	-- MatrixTutorialUI 객체 찾기
	tutorialGui = playerGui:WaitForChild("MatrixTutorialUI")
	pg_title = tutorialGui.MainFrame.TitleLabel; pg_content = tutorialGui.MainFrame.ContentLabel
	pg_prev = tutorialGui.MainFrame.PreviousButton; pg_next = tutorialGui.MainFrame.NextButton
	pg_page = tutorialGui.MainFrame.PageIndicator; pg_close = tutorialGui.MainFrame.CloseButton

	-- [수정] pg_status 변수에 StatusLabel 할당
	pg_status = tutorialGui.MainFrame:WaitForChild("StatusLabel")

	q_frame = tutorialGui.MainFrame:WaitForChild("QuizFrame")
	q_question = q_frame:WaitForChild("QuizQuestion"); q_option1 = q_frame:WaitForChild("QuizOption1")
	q_option2 = q_frame:WaitForChild("QuizOption2"); q_option3 = q_frame:WaitForChild("QuizOption3")
	q_feedback = q_frame:WaitForChild("QuizFeedback")

	-- 튜토리얼 UI("Display5") ProximityPrompt 이벤트 연결
	local display5Model = currentMap:FindFirstChild("Display5", true)
	if display5Model then
		local interactionPart = display5Model:WaitForChild("Display", 5)
		local prompt = interactionPart and interactionPart:WaitForChild("ProximityPrompt", 5)
		if prompt then
			prompt.Triggered:Connect(function()
				updateTutorialUI(1); tutorialGui.Enabled = not tutorialGui.Enabled
			end)
		end
	end

	-- 튜토리얼 UI 버튼 이벤트 연결
	pg_next.MouseButton1Click:Connect(onNextStepClicked)
	pg_prev.MouseButton1Click:Connect(function() if state.trainingStep > 1 then updateTutorialUI(math.floor(state.trainingStep - 1)) end end)
	pg_close.MouseButton1Click:Connect(function() tutorialGui.Enabled = false; updateTutorialUI(1) end)
	q_option1.MouseButton1Click:Connect(function() onQuizAnswer(q_option1.Text) end)
	q_option2.MouseButton1Click:Connect(function() onQuizAnswer(q_option2.Text) end)
	q_option3.MouseButton1Click:Connect(function() onQuizAnswer(q_option3.Text) end)

	-- 튜토리얼 모델의 클릭 이벤트 연결
	workspaceParts.x1:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x1") end)
	workspaceParts.x2:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x2") end)

	-- 프로그램 시작
	updateVisuals()
	tutorialGui.Enabled = false

	print("MatrixController: 모든 튜토리얼 기능이 성공적으로 초기화되었습니다.")
end

Initialize()

print("MatrixController: 스크립트 로드 완료.")