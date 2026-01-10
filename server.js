const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// DATABASE GIẢ LẬP
// sessions: Lưu trạng thái đang xem quảng cáo
// keys: Lưu key đã tạo thành công
const sessions = {}; 
const keys = {};

// CẤU HÌNH
const MIN_DURATION_SECONDS = 15; // Phải mất ít nhất 15s mới được coi là không bypass
const KEY_EXPIRATION_HOURS = 24;

// 1. Bước 1: Người dùng bắt đầu quy trình (Nhập HWID)
app.post('/api/start-process', (req, res) => {
    const { hwid } = req.body;
    if (!hwid) return res.status(400).json({ error: "Missing HWID" });

    // Tạo session ID duy nhất cho lần vượt link này
    const sessionId = uuidv4();
    
    sessions[sessionId] = {
        hwid: hwid,
        startTime: Date.now() // Lưu mốc thời gian bắt đầu
    };

    // Trả về Session ID để client gắn vào link Linkvertise
    res.json({ success: true, sessionId: sessionId });
});

// 2. Bước 2: Endpoint Xử lý khi Linkvertise trả về (Verify)
// Linkvertise Target URL nên đặt là: https://your-site.com/verify-page?session=...
app.post('/api/complete-process', (req, res) => {
    const { sessionId } = req.body;
    
    const session = sessions[sessionId];

    // Kiểm tra session có tồn tại không
    if (!session) {
        return res.json({ success: false, error: "Session không hợp lệ hoặc đã hết hạn." });
    }

    // --- CHỐNG BYPASS: KIỂM TRA THỜI GIAN ---
    const timeTaken = (Date.now() - session.startTime) / 1000; // Tính bằng giây
    
    if (timeTaken < MIN_DURATION_SECONDS) {
        // Nếu quay lại quá nhanh (dưới 15s) -> Chắc chắn là bypass hoặc hack
        delete sessions[sessionId]; // Xóa session phạt
        return res.json({ 
            success: false, 
            error: `Phát hiện Bypass! Bạn hoàn thành quá nhanh (${Math.floor(timeTaken)}s). Vui lòng thử lại trung thực.` 
        });
    }

    // Nếu thời gian hợp lý -> Tạo Key
    const newKey = "KEY_" + uuidv4().split('-')[0].toUpperCase();
    const expiration = Date.now() + (KEY_EXPIRATION_HOURS * 60 * 60 * 1000);

    // Lưu Key vào database chính
    keys[session.hwid] = {
        key: newKey,
        expires: expiration
    };

    // Xóa session tạm
    delete sessions[sessionId];

    res.json({ success: true, key: newKey });
});

// 3. Endpoint cho Script Roblox kiểm tra Key
app.get('/api/check-key', (req, res) => {
    const { hwid, key } = req.query;
    const record = keys[hwid];

    if (!record) return res.json({ valid: false });
    if (Date.now() > record.expires) return res.json({ valid: false, message: "Expired" });
    if (record.key !== key) return res.json({ valid: false });

    return res.json({ valid: true });
});

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));