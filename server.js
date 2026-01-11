const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const crypto = require('crypto');
const path = require('path');

const app = express();
const PORT = 3000;

// === CONFIG ===
const MONGO_URI = process.env.MONGO_URI;
const YOUR_DOMAIN = process.env.DOMAIN;
const LINKVERTISE_USER_ID = process.env.LINKVERTISE_USER_ID;
const SESSION_SECRET = process.env.SESSION_SECRET;

if (!MONGO_URI || !LINKVERTISE_USER_ID) {
    console.error("❌ LỖI: Thiếu biến môi trường trong file .env hoặc trên Server!");
    process.exit(1);
}

// Kết nối DB
mongoose.connect(MONGO_URI).then(() => console.log('✅ DB Connected'));

// === DATABASE SCHEMAS ===

// 1. Bảng USER (Lưu tài khoản vĩnh viễn theo HWID)
const UserSchema = new mongoose.Schema({
    hwid: { type: String, unique: true, required: true },
    key: { type: String, default: null },
    keyExpires: { type: Date, default: null },
    ip: String,
    totalKeysGenerated: { type: Number, default: 0 }, // Đếm số lần lấy key (Thống kê cho vui)
    lastLogin: { type: Date, default: Date.now }
});

// 2. Bảng SESSION (Lưu phiên giao dịch tạm thời để ẩn HWID trên URL)
const SessionSchema = new mongoose.Schema({
    sessionId: String, // Cái này sẽ hiện trên URL (?id=...)
    hwid: String,      // Map về HWID thật
    secretToken: String,
    verified: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now, expires: 600 } // Link sống 10 phút
});

const UserModel = mongoose.model('User', UserSchema);
const SessionModel = mongoose.model('Session', SessionSchema);

app.set('trust proxy', true);
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: true
}));

// ================= API LOGIC =================

// 1. HANDSHAKE (Script gọi): Đăng nhập/Đăng ký tự động
app.post('/api/handshake', async (req, res) => {
    const { hwid } = req.body;
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (!hwid) return res.json({ success: false });

    // Tự động tạo hoặc cập nhật User
    let user = await UserModel.findOne({ hwid });
    if (!user) {
        user = await UserModel.create({ hwid, ip });
        console.log(`[NEW USER] Created account for HWID: ${hwid}`);
    } else {
        user.lastLogin = Date.now();
        user.ip = ip;
        await user.save();
    }

    // Tạo Session tạm để giấu HWID
    const sessionId = crypto.randomBytes(12).toString('hex');
    const secretToken = crypto.randomBytes(16).toString('hex');

    await SessionModel.create({ sessionId, hwid, secretToken });

    // Trả về link sạch
    res.json({ success: true, url: `${YOUR_DOMAIN}/?id=${sessionId}` });
});

// 2. GET PROFILE (Web gọi): Lấy thông tin tài khoản để hiển thị Dashboard
app.post('/api/profile', async (req, res) => {
    const { sessionId } = req.body;
    
    // Tìm session
    const session = await SessionModel.findOne({ sessionId });
    if (!session) return res.json({ success: false, error: "Session Invalid" });

    // Tìm User từ session
    const user = await UserModel.findOne({ hwid: session.hwid });
    if (!user) return res.json({ success: false, error: "User Not Found" });

    // Check trạng thái Key
    let keyStatus = "NONE";
    let timeLeft = 0;
    
    if (user.key && user.keyExpires > new Date()) {
        keyStatus = "ACTIVE";
        timeLeft = Math.floor((new Date(user.keyExpires) - new Date()) / 1000);
    } else if (user.key && user.keyExpires <= new Date()) {
        keyStatus = "EXPIRED";
    }

    res.json({ 
        success: true, 
        hwidShort: user.hwid.substring(0, 8) + "...", // Chỉ hiện 1 phần HWID cho đẹp
        keyStatus: keyStatus,
        currentKey: keyStatus === "ACTIVE" ? user.key : null,
        timeLeft: timeLeft,
        totalGenerations: user.totalKeysGenerated
    });
});

// 3. START LINKVERTISE (Khi bấm Get Key)
app.post('/api/start-process', async (req, res) => {
    const { sessionId } = req.body;
    const session = await SessionModel.findOne({ sessionId });
    
    if (!session) return res.json({ success: false });

    // Tạo Dynamic Link
    const destination = `${YOUR_DOMAIN}/api/callback?sid=${sessionId}&t=${session.secretToken}`;
    const base64 = Buffer.from(destination).toString('base64');
    const link = `https://link-to.net/${LINKVERTISE_USER_ID}/${Math.floor(Math.random()*1000)}/dynamic/?r=${base64}`;

    res.json({ success: true, link });
});

// 4. CALLBACK
app.get('/api/callback', async (req, res) => {
    const { sid, t } = req.query;
    const session = await SessionModel.findOne({ sessionId: sid });
    
    if (session && session.secretToken === t) {
        session.verified = true;
        await session.save();
        res.redirect(`/?id=${sid}#completed`);
    } else {
        res.send("Invalid Token");
    }
});

// 5. GENERATE KEY (Hoàn tất)
app.post('/api/complete-process', async (req, res) => {
    const { sessionId } = req.body;
    const session = await SessionModel.findOne({ sessionId });

    if (!session || !session.verified) return res.json({ success: false, error: "Unverified" });

    // Tạo Key mới
    const newKey = `HAIRKEY_${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const expires = new Date(Date.now() + 24*60*60*1000); // 24h

    // Cập nhật vào User
    const user = await UserModel.findOne({ hwid: session.hwid });
    user.key = newKey;
    user.keyExpires = expires;
    user.totalKeysGenerated += 1;
    await user.save();

    await SessionModel.deleteOne({ sessionId }); // Xóa session cho sạch

    res.json({ success: true, key: newKey });
});

// 6. CHECK KEY (Cho Roblox)
app.get('/api/check-key', async (req, res) => {
    const { hwid, key } = req.query;
    const user = await UserModel.findOne({ hwid });

    if (user && user.key === key && user.keyExpires > new Date()) {
        return res.json({ valid: true });
    }
    return res.json({ valid: false });
});

app.listen(PORT, () => console.log('Server running...'));