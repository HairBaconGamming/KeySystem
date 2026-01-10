const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const crypto = require('crypto'); // Thêm thư viện mã hóa để tạo Key ngầu hơn

const app = express();
const PORT = 3000;

// CẤU HÌNH BẢO MẬT
const KEY_DURATION_HOURS = 24; // 1. Thời lượng Key: 24h
const MIN_WATCH_TIME = 15; // Giây
const ALLOWED_IP_CHANGE = false; // false = Bắt buộc cùng IP mới cho lấy key

app.set('trust proxy', true); // Để lấy đúng IP trên Render/Heroku
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// DATABASE (Nên dùng MongoDB nếu muốn lưu vĩnh viễn, đây là RAM)
const sessions = {}; 
const keys = {};
const rateLimit = {}; // Chống spam

// Hàm lấy IP thật của người dùng
function getClientIp(req) {
    return (req.headers['x-forwarded-for'] || req.socket.remoteAddress).split(',')[0].trim();
}

// 1. API: Bắt đầu phiên (Start)
app.post('/api/start-process', (req, res) => {
    const { hwid } = req.body;
    const ip = getClientIp(req);

    if (!hwid) return res.status(400).json({ error: "Thiếu HWID" });

    // Chống Spam: Mỗi IP chỉ được request 1 lần mỗi 5 giây
    if (rateLimit[ip] && Date.now() - rateLimit[ip] < 5000) {
        return res.json({ success: false, error: "Thao tác quá nhanh. Chờ chút!" });
    }
    rateLimit[ip] = Date.now();

    // Tạo Session ID
    const sessionId = uuidv4();
    
    sessions[sessionId] = {
        hwid: hwid,
        ip: ip, // 2. Lưu IP người bắt đầu
        startTime: Date.now()
    };

    console.log(`[START] HWID: ${hwid} | IP: ${ip}`);
    res.json({ success: true, sessionId: sessionId });
});

// 2. API: Hoàn thành & Lấy Key (Verify)
app.post('/api/complete-process', (req, res) => {
    const { sessionId } = req.body;
    const currentIp = getClientIp(req);
    
    const session = sessions[sessionId];

    // Check Session tồn tại
    if (!session) {
        return res.json({ success: false, error: "Session không tồn tại hoặc đã hết hạn." });
    }

    // 3. SECURITY: Check IP (Chống share link)
    if (!ALLOWED_IP_CHANGE && session.ip !== currentIp) {
        delete sessions[sessionId]; // Phạt xóa session luôn
        return res.json({ 
            success: false, 
            error: "IP Thay đổi! Không được nhờ người khác lấy Key hộ." 
        });
    }

    // 4. SECURITY: Check Thời gian (Chống Bypass/Hack)
    const timeTaken = (Date.now() - session.startTime) / 1000;
    if (timeTaken < MIN_WATCH_TIME) {
        delete sessions[sessionId]; // Phạt
        return res.json({ 
            success: false, 
            error: `Bypass detected! Quá nhanh (${Math.floor(timeTaken)}s). Yêu cầu xem đủ ${MIN_WATCH_TIME}s.` 
        });
    }

    // TẠO KEY (Format: HAIRKEY_RandomString)
    // Dùng crypto để tạo chuỗi ngẫu nhiên khó đoán hơn UUID
    const randomPart = crypto.randomBytes(8).toString('hex').toUpperCase();
    const newKey = `HAIRKEY_${randomPart}`;
    
    const expiresAt = Date.now() + (KEY_DURATION_HOURS * 60 * 60 * 1000);

    // Lưu Key vào Database
    keys[session.hwid] = {
        key: newKey,
        expires: expiresAt,
        createdIp: currentIp
    };

    // Xóa session để không dùng lại được
    delete sessions[sessionId];

    console.log(`[SUCCESS] Key Generated for ${session.hwid}`);
    res.json({ success: true, key: newKey });
});

// 3. API: Script Roblox Check Key
app.get('/api/check-key', (req, res) => {
    const { hwid, key } = req.query;
    
    const record = keys[hwid];

    if (!record) {
        return res.json({ valid: false, message: "HWID chưa có Key." });
    }

    // Check thời hạn
    if (Date.now() > record.expires) {
        delete keys[hwid]; // Xóa key hết hạn
        return res.json({ valid: false, message: "Key đã hết hạn. Vui lòng lấy lại." });
    }

    // Check khớp Key
    if (record.key !== key) {
        return res.json({ valid: false, message: "Key sai!" });
    }

    // Thành công
    // Tính thời gian còn lại để hiển thị (Optional)
    const hoursLeft = Math.floor((record.expires - Date.now()) / (1000 * 60 * 60));
    return res.json({ valid: true, message: `Key hợp lệ! Còn lại ${hoursLeft} giờ.` });
});

app.listen(PORT, () => {
    console.log(`Server Secure is running at port ${PORT}`);
});