const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { GoogleGenerativeAI } = require("@google/generative-ai");

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Cấu hình Gemini API
const genAI = new GoogleGenerativeAI("YOUR_GEMINI_API_KEY");
const model = genAI.getGenerativeModel({ model: "gemini-pro"});

// Định nghĩa tính cách (System Instruction)
const HEALTH_PROMPT = `
Bạn là trợ lý y tế.
- Chỉ tư vấn dựa trên kiến thức y khoa chuẩn xác.
- Nếu người dùng hỏi về bệnh nặng, hãy khuyên họ đi khám bác sĩ.
- Luôn kèm câu: "Thông tin chỉ mang tính tham khảo".
`;

const STORY_PROMPT = `
Bạn là người kể chuyện sáng tạo, giọng văn ấm áp.
Hãy kể chuyện ngắn gọn, thú vị.
`;

app.post('/api/chat', async (req, res) => {
    try {
        const { message, mode } = req.body; // mode: 'health' hoặc 'story'

        // Chọn prompt dựa trên chế độ user chọn
        const systemInstruction = mode === 'health' ? HEALTH_PROMPT : STORY_PROMPT;

        // Ghép prompt hệ thống với câu hỏi user
        const fullPrompt = `${systemInstruction}\n\nUser: ${message}\nAI:`;

        const result = await model.generateContent(fullPrompt);
        const response = await result.response;
        const text = response.text();

        res.json({ reply: text });
    } catch (error) {
        console.error(error);
        res.status(500).json({ reply: "Xin lỗi, server đang bận." });
    }
});

app.listen(3000, () => console.log('Server chạy tại port 3000'));