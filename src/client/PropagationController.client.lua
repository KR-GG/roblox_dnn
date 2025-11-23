--// 서비스 및 모듈 불러오기 //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- [신규] 튜토리얼 전용 모듈들을 불러옵니다.
local TutorialMath = require(ReplicatedStorage.Shared.Modules.TutorialMath)
local TutorialVisualizer = require(ReplicatedStorage.Shared.Visualization.TutorialVisualizer)
local ActivationFunctions = require(ReplicatedStorage.Shared.CoreLogic.ActivationFunctions)
local MapService = require(ReplicatedStorage.Shared.Services.MapService)

--// 변수 선언 //--
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
	inputs = { x1 = 1, x2 = 1 }, -- AND 게이트 [1, 1] 테스트
	weights = { x1 = 0.5, x2 = -0.3 }, -- 초기 랜덤 가중치
	bias = 0.1,
	target = 1, -- AND 게이트 [1,1]의 정답은 1
	activationName = "Sigmoid",
	trainingStep = 1, quizAttempts = 0, currentQuizAnswer = nil, currentQuizExplanation = nil,
	lastWeightedSum = 0, lastOutput = 0, lastError = 0, lastDelta = 0,
	lastGradients = { dw1 = 0, dw2 = 0, db = 0 }
}

-- GUI 및 모듈 인스턴스 변수
local visuals
local workspaceParts = {}
local lastOutput = 0
local lastPreActivationSum = 0

-- PropagationTutorialUI ("Display4") 객체
local tutorialGui, pg_title, pg_content, pg_prev, pg_next, pg_page, pg_close
local q_frame, q_question, q_option1, q_option2, q_option3, q_feedback

-- [수정] 튜토리얼 단계를 더 세분화
local TUTORIAL_STEPS = {
	[1] = { title = "Step 1: The Goal", content = "Let's train this neuron to solve the <b>AND</b> gate. The target for `[1, 1]` is `1`.\n\nClick <b>[Start Forward Pass]</b>.", buttonText = "Start Forward Pass" },
	[2] = { title = "Step 2: Weighted Sum", content = "First, we calculate the <b>Weighted Sum</b>: (x1*w1) + (x2*w2) + bias.\n\nClick <b>[Calculate Sum]</b>.", buttonText = "Calculate Sum" },
	[3] = { title = "Step 3: Activation", content = "The sum is <b>%.2f</b>. Now, we apply the <b>Sigmoid</b> function to squash this value between 0 and 1.\n\nClick <b>[Apply Activation]</b>.", buttonText = "Apply Activation" },
	[4] = { title = "Step 4: Prediction", content = "The final prediction is <b>%.2f</b>. The target was <b>1.0</b>.\n\nClick <b>[Calculate Error]</b>.", buttonText = "Calculate Error" },
	[5] = { title = "Step 5: The Error", content = "Error = (Target - Prediction) = <b>%.2f</b>.\n\nNow we start <b>Backpropagation</b>. We need the 'Derivative' (slope) of the Sigmoid function.\n\nClick <b>[Next]</b>.", buttonText = "Next" },
	[6] = { title = "Step 6: The Delta", content = "The 'Delta' (Error * Derivative) is the core error signal.\nWe have the Error (%.2f), but we need the Derivative.\n\nClick <b>[Calculate Gradients]</b>.", buttonText = "Calculate Gradients" },
	[7] = { title = "Step 7: Backpropagation", content = "We send the 'Delta' signal backward to find the 'blame' (Gradients) for each weight.\n\nClick <b>[Show Blame]</b>.", buttonText = "Show Blame (Animation)" },
	[8] = { title = "Step 8: Gradient Descent", content = "We found the gradients (dw1, dw2, db). Now we use them to update the weights.\n\nClick <b>[Apply Update]</b>.", buttonText = "Apply Update (Learn)" },
	[9] = { title = "Step 9: Check Results", content = "Learning complete! The network has been updated.\n\nClick <b>[Run Forward Pass]</b> again to see if the prediction has improved.", buttonText = "Run Forward Pass" },
	[10] = { title = "Step 10: Free Experiment", content = "The neuron is smarter! Keep training or click the <b>Input Blocks</b> to test new values.", buttonText = "Run Forward Pass (Again)" }
}

-- [수정] 퀴즈 데이터베이스 (미분 계산 퀴즈 추가)
local QUIZ_DATA = {
	["weighted_sum"] = {
		getQuestion = function(s) return string.format("QUIZ: (1.0 * 0.5) + (1.0 * -0.3) + 0.1 = ?\n(Hint: 0.5 - 0.3 + 0.1)") end,
		getOptions = function() return {
			opt1 = "0.3", opt2 = "0.5", opt3 = "0.9", answer = "0.3",
			explanation = "<b>Answer: 0.3</b>. The weighted sum is (1.0 * 0.5) + (1.0 * -0.3) + 0.1 = 0.5 - 0.3 + 0.1 = 0.3."
			} end
	},
	["activation_predict"] = {
		getQuestion = function(s) return string.format("QUIZ: The sum is %.2f (a small positive number). What will the <b>Sigmoid</b> function output?", s) end,
		getOptions = function() return {
			opt1 = "A value near 0", opt2 = "A value near 0.5", opt3 = "A value near 1.0",
			answer = "A value near 0.5",
			explanation = "<b>Answer: Near 0.5</b>. The Sigmoid function (σ) squashes numbers. σ(0) is exactly 0.5, so a small positive number like 0.3 will result in a value slightly above 0.5."
			} end
	},
	["error_sign"] = {
		getQuestion = function(o) return string.format("QUIZ: Prediction is %.2f, Target is 1.0. Is the error (Target - Prediction) Positive or Negative?", o) end,
		getOptions = function() return {
			opt1 = "Positive (Prediction is too low)", opt2 = "Negative (Prediction is too high)", opt3 = "Zero",
			answer = "Positive (Prediction is too low)",
			explanation = "<b>Answer: Positive</b>. The error is 1.0 - %.2f = %.2f. Since the result is positive, we need to *increase* the prediction."
			} end
	},
	["derivative_why"] = {
		getQuestion = function() return "QUIZ: Why do we need the <b>Derivative</b> (the slope of the graph)?" end,
		getOptions = function() return {
			opt1 = "To know the 'direction' and 'steepness' of the error.",
			opt2 = "To make the error value positive.",
			opt3 = "We don't, it's an extra step.",
			answer = "To know the 'direction' and 'steepness' of the error.",
			explanation = "<b>Answer: Direction & Steepness</b>. The derivative tells us how much a change in the sum affects the output. It's crucial for knowing how strongly to adjust the weights."
			} end
	},
	-- [신규] 미분값 계산 퀴즈
	["derivative_calculation"] = {
		getQuestion = function(output) 
			return string.format("QUIZ: The formula for Sigmoid's derivative is <b>output * (1 - output)</b>.\n\nGiven our output is <b>%.2f</b>, what is the derivative?", output)
		end,
		getOptions = function(output)
			local correct = output * (1 - output)
			local wrong1 = output * (1 - output) + 0.1
			local wrong2 = output * (1 + output)
			return {
				opt1 = string.format("%.3f", wrong1),
				opt2 = string.format("%.3f", correct),
				opt3 = string.format("%.3f", wrong2),
				answer = string.format("%.3f", correct),
				explanation = string.format("<b>Answer: %.3f</b>. The calculation is output * (1 - output), which is %.2f * (1 - %.2f) = %.3f.", correct, output, output, correct)
			}
		end
	},
	["gradient_direction"] = {
		getQuestion = function() return "QUIZ: Our 'Delta' is positive (we need a <b>higher</b> output). How should we adjust the weight for a <b>positive input (x1=1)</b>?" end,
		getOptions = function(d) 
			local needsIncrease = d > 0
			return {
				opt1 = "Increase it (to push the output up)",
				opt2 = "Decrease it (to pull the output down)",
				opt3 = "Stay the Same",
				answer = if needsIncrease then "Increase it (to push the output up)" else "Decrease it (to pull the output down)",
				explanation = "<b>Answer: Increase</b>. To increase the final sum, a weight connected to a positive input (1.0) must also *increase*."
			} end
	},
	["gradient_descent"] = {
		getQuestion = function() return "QUIZ: What is this process of using the gradient (blame) to slowly 'descend' towards the minimum error called?" end,
		getOptions = function() return {
			opt1 = "Forward Propagation", opt2 = "Gradient Descent", opt3 = "Activation",
			answer = "Gradient Descent",
			explanation = "<b>Answer: Gradient Descent</b>. It's the core optimization algorithm used to train most neural networks!"
			} end
	}
}

--// 함수 정의 //--

--- 모든 시각화(파트 색상, 빔, SurfaceGUI)를 현재 state 기준으로 업데이트
local function updateVisuals()
	local currentActivationFunc = ActivationFunctions[state.activationName]
	local output, preActivationSum = TutorialMath.calculateOutput(state.inputs, state.weights, state.bias, currentActivationFunc)
	state.lastOutput = output; state.lastWeightedSum = preActivationSum

	-- 1. 입력 파트 색상 및 텍스트 업데이트
	local function getTextColor(value) return if value > 0.5 then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255) end

	if workspaceParts.x1 then
		workspaceParts.x1.Color = Color3.new(state.inputs.x1, state.inputs.x1, state.inputs.x1) -- 0:검은색, 1:흰색
		workspaceParts.x1.SurfaceGui.TextLabel.Text = state.inputs.x1
		workspaceParts.x1.SurfaceGui.TextLabel.TextColor3 = getTextColor(state.inputs.x1)
	end
	if workspaceParts.x2 then
		workspaceParts.x2.Color = Color3.new(state.inputs.x2, state.inputs.x2, state.inputs.x2)
		workspaceParts.x2.SurfaceGui.TextLabel.Text = state.inputs.x2
		workspaceParts.x2.SurfaceGui.TextLabel.TextColor3 = getTextColor(state.inputs.x2)
	end
	if workspaceParts.y then
		workspaceParts.y.Color = Color3.new(output, output, output)
		workspaceParts.y.SurfaceGui.TextLabel.Text = string.format("%.2f", output)
		workspaceParts.y.SurfaceGui.TextLabel.TextColor3 = getTextColor(output)
	end
	if workspaceParts.Neuron then
		workspaceParts.Neuron.SurfaceGui.TextLabel.Text = string.format("%.2f", preActivationSum)
		workspaceParts.Neuron.SurfaceGui.TextLabel.TextColor3 = getTextColor(output)
	end

	-- 2. 가중치(Beam) 색상 및 라벨 텍스트 업데이트
	local beam1 = workspaceParts.x1:FindFirstChildOfClass("Beam")
	local beam2 = workspaceParts.x2:FindFirstChildOfClass("Beam")

	if beam1 then
		-- 가중치 부호에 따라 색상 변경 (양수: 초록, 음수: 빨강)
		beam1.Color = if state.weights.x1 >= 0 then ColorSequence.new(Color3.new(0,1,0)) else ColorSequence.new(Color3.new(1,0,0))
		-- 1단계에서 추가한 WeightLabel을 찾아 텍스트 업데이트
		local labelGui = workspaceParts.x1:FindFirstChildOfClass("BillboardGui")
		if labelGui then
			labelGui.WeightLabel.Text = string.format("w1: %.2f", state.weights.x1)
		end
	end

	if beam2 then
		beam2.Color = if state.weights.x2 >= 0 then ColorSequence.new(Color3.new(0,1,0)) else ColorSequence.new(Color3.new(1,0,0))
		local labelGui = workspaceParts.x2:FindFirstChildOfClass("BillboardGui")
		if labelGui then
			labelGui.WeightLabel.Text = string.format("w2: %.2f", state.weights.x2)
		end
	end

	-- 3. 편향(Bias) 값에 따라 뉴런 파트 색상 업데이트
	if workspaceParts.Neuron then
		-- 편향 값을 0~1 범위로 정규화 (예: -1 ~ 1 범위를 0 ~ 1로)
		local normalizedBias = math.clamp(state.bias * 0.5 + 0.5, 0, 1)
		-- 파란색(낮음/음수) ~ 회색(중립) ~ 주황색(높음/양수)
		workspaceParts.Neuron.Color = Color3.fromHSV(0.66 - (normalizedBias * 0.6), 0.8, 0.9)
	end
end

--- 튜토리얼 UI 페이지 업데이트
local function updateTutorialUI(step)
	state.trainingStep = step
	local pageData = TUTORIAL_STEPS[state.trainingStep]
	if not pageData then return end

	local content = pageData.content
	if state.trainingStep == 3 then content = string.format(pageData.content, state.lastWeightedSum)
	elseif state.trainingStep == 4 then content = string.format(pageData.content, state.lastOutput)
	elseif state.trainingStep == 5 then 
		state.lastError = TutorialMath.calculateError(state.lastOutput, state.target)
		content = string.format(pageData.content, state.lastError) 
	elseif state.trainingStep == 6 then 
		state.lastDerivative = TutorialMath.getActivationDerivative(state.activationName, state.lastOutput)
		state.lastDelta = TutorialMath.calculateDelta(state.lastError, state.lastDerivative)
		content = string.format(pageData.content, state.lastError, state.lastDelta) 
	end

	pg_title.Text = pageData.title; pg_content.Text = content
	pg_page.Text = string.format("Step %d / %d", state.trainingStep, #TUTORIAL_STEPS); pg_next.Text = pageData.buttonText
	pg_prev.Visible = (state.trainingStep > 1); q_frame.Visible = false; pg_next.Visible = true
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

--- 퀴즈 정답 처리 (2단계 기회, 단계 세분화)
local function onQuizAnswer(selectedAnswer)
	if selectedAnswer == state.currentQuizAnswer then
		q_feedback.Text = "Correct! Advancing to the next step..."
		q_feedback.TextColor3 = Color3.fromRGB(0, 255, 0); task.wait(1.5)

		if state.trainingStep == 2.5 then updateTutorialUI(3)
		elseif state.trainingStep == 3.5 then updateTutorialUI(4)
		elseif state.trainingStep == 4.5 then updateTutorialUI(5)
		elseif state.trainingStep == 5.5 then showQuiz("derivative_calculation", state.lastOutput); state.trainingStep = 5.6
		elseif state.trainingStep == 5.6 then updateTutorialUI(6)
		elseif state.trainingStep == 7.5 then updateTutorialUI(8)
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

			if state.trainingStep == 2.5 then updateTutorialUI(3)
			elseif state.trainingStep == 3.5 then updateTutorialUI(4)
			elseif state.trainingStep == 4.5 then updateTutorialUI(5)
			elseif state.trainingStep == 5.5 then showQuiz("derivative_calculation", state.lastOutput); state.trainingStep = 5.6
			elseif state.trainingStep == 5.6 then updateTutorialUI(6)
			elseif state.trainingStep == 7.5 then updateTutorialUI(8)
			elseif state.trainingStep == 8.5 then updateTutorialUI(9)
			end
		end
	end
end

--- 튜토리얼 단계 실행 (Next 버튼)
local function onNextStepClicked()
	if q_frame.Visible then return end

	local step = state.trainingStep
	if step == 1 then
		updateVisuals()
		TutorialVisualizer.playForwardPass(workspaceParts, state.inputs)
		updateTutorialUI(2)
	elseif step == 2 then
		state.lastWeightedSum = TutorialMath.calculateWeightedSum(state.inputs, state.weights, state.bias)
		TutorialVisualizer.showCalculationText(workspaceParts.Neuron, string.format("(%.1f*%.1f)+(%.1f*%.1f)+%.1f=%.2f", state.inputs.x1, state.weights.x1, state.inputs.x2, state.weights.x2, state.bias, state.lastWeightedSum), 3)
		state.trainingStep = 2.5; task.wait(3)
		showQuiz("weighted_sum", nil)
	elseif step == 3 then
		state.lastOutput = TutorialMath.applyActivation(state.activationName, state.lastWeightedSum)
		TutorialVisualizer.playActivation(workspaceParts.Neuron, state.lastOutput, workspaceParts.y)
		updateVisuals()
		state.trainingStep = 3.5; task.wait(2)
		showQuiz("activation_predict", state.lastWeightedSum)
	elseif step == 4 then
		state.lastError = TutorialMath.calculateError(state.lastOutput, state.target)
		updateTutorialUI(5)
		state.trainingStep = 4.5; task.wait(1.5)
		showQuiz("error_sign", state.lastOutput)
	elseif step == 5 then
		state.lastDerivative = TutorialMath.getActivationDerivative(state.activationName, state.lastOutput)
		state.trainingStep = 5.5; task.wait(1)
		showQuiz("derivative_why", nil)
	elseif step == 6 then
		state.lastDelta = TutorialMath.calculateDelta(state.lastError, state.lastDerivative)
		state.lastGradients.dw1, state.lastGradients.dw2, state.lastGradients.db = TutorialMath.calculateGradients(state.inputs, state.lastDelta)
		updateTutorialUI(7)
	elseif step == 7 then
		TutorialVisualizer.playBackwardPass(workspaceParts)
		state.trainingStep = 7.5; task.wait(3)
		showQuiz("gradient_direction", state.lastDelta)
	elseif step == 8 then
		local newWeights, newBias = TutorialMath.applyUpdate(state.weights, state.bias, state.lastGradients.dw1, state.lastGradients.dw2, state.lastGradients.db)
		state.weights = newWeights; state.bias = newBias
		updateVisuals()
		state.trainingStep = 8.5; task.wait(1)
		showQuiz("gradient_descent", nil)
	elseif step == 9 or step == 10 then
		updateVisuals()
		TutorialVisualizer.playForwardPass(workspaceParts, state.inputs)
		state.trainingStep = 9.5; task.wait(1.2)
		updateTutorialUI(10)
	end
end

--- 입력 파트 클릭 (10단계에서만 활성화)
local function onInputPartClicked(partName)
	if q_frame.Visible then return end
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
	print("PropagationController: ClientReady 신호를 받았습니다. 초기화를 시작합니다.")

	local currentMap = MapService.getCurrentMap()
	if not currentMap then error("PropagationController 초기화 실패: 현재 맵을 찾을 수 없습니다.") return end
	local tutorialModel = currentMap:WaitForChild("TutorialPerceptron")

	-- workspaceParts 테이블 채우기 (2-Input)
	workspaceParts = { container = tutorialModel, x1 = tutorialModel:WaitForChild("x1"), x2 = tutorialModel:WaitForChild("x2"), Neuron = tutorialModel:WaitForChild("Neuron"), y = tutorialModel:WaitForChild("y") }
	visuals = {} -- 이 튜토리얼은 Visuals 모듈을 사용하지 않고, updateVisuals()가 직접 처리합니다. (기존 PerceptronVisuals 모듈과 충돌 방지)

	tutorialGui = playerGui:WaitForChild("PropagationTutorialUI")
	pg_title = tutorialGui.MainFrame.TitleLabel
	pg_content = tutorialGui.MainFrame.ContentLabel
	pg_prev = tutorialGui.MainFrame.PreviousButton
	pg_next = tutorialGui.MainFrame.NextButton
	pg_page = tutorialGui.MainFrame.PageIndicator
	pg_close = tutorialGui.MainFrame.CloseButton
	q_frame = tutorialGui.MainFrame:WaitForChild("QuizFrame")
	q_question = q_frame:WaitForChild("QuizQuestion")
	q_option1 = q_frame:WaitForChild("QuizOption1")
	q_option2 = q_frame:WaitForChild("QuizOption2")
	q_option3 = q_frame:WaitForChild("QuizOption3")
	q_feedback = q_frame:WaitForChild("QuizFeedback")
	
	-- 튜토리얼 UI("Display3") ProximityPrompt 이벤트 연결
	local display3Model = currentMap:FindFirstChild("Display3", true) -- 스튜디오에서 만든 디스플레이 이름
	if display3Model then
		local interactionPart = display3Model:WaitForChild("Display", 5)
		local prompt = interactionPart and interactionPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			print("There's display3 prompt")
			prompt.Triggered:Connect(function()
				updateTutorialUI(1)
				tutorialGui.Enabled = not tutorialGui.Enabled
			end)
		end
	end

	-- 튜토리얼 UI 버튼 이벤트 연결
	pg_next.MouseButton1Click:Connect(onNextStepClicked)
	pg_prev.MouseButton1Click:Connect(function() updateTutorialUI(state.trainingStep - 1) end)
	pg_close.MouseButton1Click:Connect(function() tutorialGui.Enabled = false; updateTutorialUI(1) end)

	-- 퀴즈 버튼 이벤트 연결
	q_option1.MouseButton1Click:Connect(function() onQuizAnswer(q_option1.Text) end)
	q_option2.MouseButton1Click:Connect(function() onQuizAnswer(q_option2.Text) end)
	q_option3.MouseButton1Click:Connect(function() onQuizAnswer(q_option3.Text) end)

	-- 튜토리얼 모델의 클릭 이벤트 연결
	workspaceParts.x1:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x1") end)
	workspaceParts.x2:WaitForChild("ClickDetector").MouseClick:Connect(function() onInputPartClicked("x2") end)

	-- 프로그램 시작
	updateVisuals() -- 초기 상태 시각화
	tutorialGui.Enabled = false

	print("PropagationController: 모든 튜토리얼 기능이 성공적으로 초기화되었습니다.")
end

Initialize()

print("PropagationController: 스크립트 로드 완료. ClientReady 신호를 기다립니다...")
