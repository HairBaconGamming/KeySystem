require('dotenv').config();

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const session = require('express-session');
const crypto = require('crypto');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// === CONFIG ===
const MONGO_URI = process.env.MONGO_URI;
const YOUR_DOMAIN = process.env.DOMAIN;
const LINKVERTISE_USER_ID = process.env.LINKVERTISE_USER_ID;
const ADMIN_USER = process.env.ADMIN_USER;
const ADMIN_PASS = process.env.ADMIN_PASS;
const SESSION_SECRET = process.env.SESSION_SECRET;
const CLOUDFLARE_SECRET_KEY = process.env.CLOUDFLARE_SECRET_KEY;

// CẤU HÌNH SỐ BƯỚC (STEP)
const TOTAL_STEPS = 2; 

if (!MONGO_URI || !LINKVERTISE_USER_ID) {
    console.error("❌ CRITICAL ERROR: Missing .env configuration!");
    process.exit(1);
}

mongoose.connect(MONGO_URI).then(() => console.log('✅ Connected to MongoDB Atlas'));

// === SCHEMAS ===
const UserSchema = new mongoose.Schema({
    hwid: { type: String, unique: true, required: true },
    key: { type: String, default: null },
    keyExpires: { type: Date, default: null },
    ip: String,
    totalGenerations: { type: Number, default: 0 },
    lastLogin: { type: Date, default: Date.now }
});

const SessionSchema = new mongoose.Schema({
    sessionId: { type: String, unique: true },
    hwid: String,
    secretToken: String,
    
    // THAY ĐỔI: Dùng biến đếm số bước thay vì verified boolean
    currentStep: { type: Number, default: 0 }, 
    
    createdAt: { type: Date, default: Date.now, expires: 3600 } // 30 phút
});

const UserModel = mongoose.model('User', UserSchema);
const SessionModel = mongoose.model('Session', SessionSchema);

// === MIDDLEWARE ===
app.set('trust proxy', true);
app.use(cors());
app.use(express.json());
app.use(express.static('public'));
app.use(session({ secret: SESSION_SECRET, resave: false, saveUninitialized: true }));

function getClientIp(req) {
    return (req.headers['x-forwarded-for'] || req.socket.remoteAddress).split(',')[0].trim();
}

function checkAdminAuth(req, res, next) {
    if (req.session.isAdmin) next();
    else res.status(403).json({ error: "Unauthorized" });
}

// ================= API ROUTES =================

// 1. HANDSHAKE
app.post('/api/handshake', async (req, res) => {
    try {
        const { hwid } = req.body;
        const ip = getClientIp(req);
        if (!hwid) return res.json({ success: false, error: "Missing HWID" });

        let user = await UserModel.findOne({ hwid });
        if (!user) {
            user = await UserModel.create({ hwid, ip });
        } else {
            user.ip = ip;
            user.lastLogin = Date.now();
            await user.save();
        }

        const sessionId = crypto.randomBytes(12).toString('hex');
        const secretToken = crypto.randomBytes(16).toString('hex');

        // Khởi tạo session với bước 0
        await SessionModel.create({ sessionId, hwid, secretToken, currentStep: 0 });

        res.json({ success: true, url: `${YOUR_DOMAIN}/?id=${sessionId}` });
    } catch (e) { res.json({ success: false }); }
});

// 2. CHECK KEY
app.get('/api/check-key', async (req, res) => {
    try {
        const { hwid, key } = req.query;
        const user = await UserModel.findOne({ hwid });
        if (!user) return res.json({ valid: false });
        if (user.key === key && user.keyExpires > new Date()) return res.json({ valid: true });
        return res.json({ valid: false });
    } catch (e) { res.json({ valid: false }); }
});

// 3. PROFILE (Cập nhật để trả về số bước)
app.post('/api/profile', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = await SessionModel.findOne({ sessionId });
        if (!session) return res.json({ success: false, error: "Session Invalid" });

        const user = await UserModel.findOne({ hwid: session.hwid });
        if (!user) return res.json({ success: false, error: "User Not Found" });

        let keyStatus = "NONE";
        let timeLeft = 0;
        if (user.key && user.keyExpires > new Date()) {
            keyStatus = "ACTIVE";
            timeLeft = Math.floor((new Date(user.keyExpires) - new Date()) / 1000);
        } else if (user.key) keyStatus = "EXPIRED";

        res.json({
            success: true,
            hwidShort: user.hwid.substring(0, 8) + "...",
            keyStatus: keyStatus,
            currentKey: keyStatus === "ACTIVE" ? user.key : null,
            timeLeft: timeLeft,
            totalGenerations: user.totalGenerations,
            // Gửi thêm thông tin Step về Client
            currentStep: session.currentStep,
            totalSteps: TOTAL_STEPS
        });
    } catch (e) { res.json({ success: false }); }
});

// 4. START PROCESS (Tạo Link)
app.post('/api/start-process', async (req, res) => {
    try {
        const { sessionId, cfToken } = req.body;
        
        // --- TURNSTILE CHECK ---
        if (!cfToken) return res.json({ success: false, error: "Captcha Required" });
        const cfVerify = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ secret: CLOUDFLARE_SECRET_KEY, response: cfToken })
        });
        const cfData = await cfVerify.json();
        if (!cfData.success) return res.json({ success: false, error: "Bot Detected" });
        // -----------------------

        const session = await SessionModel.findOne({ sessionId });
        if (!session) return res.json({ success: false, error: "Session Invalid" });

        if (session.currentStep >= TOTAL_STEPS) return res.json({ success: false, error: "Already Completed" });

        // Tạo Linkvertise
        const targetUrl = `${YOUR_DOMAIN}/api/callback?sid=${sessionId}&t=${session.secretToken}`;
        const base64Url = Buffer.from(targetUrl).toString('base64');
        const randomPath = Math.floor(Math.random() * 99999);
        const linkvertiseLink = `https://link-to.net/${LINKVERTISE_USER_ID}/${randomPath}/dynamic/?r=${base64Url}`;

        res.json({ success: true, link: linkvertiseLink });
    } catch (e) { res.json({ success: false, error: e.message }); }
});

// 5. CALLBACK (Xử lý tăng bước)
app.get('/api/callback', (req, res) => {
    const { sid, t } = req.query;
    // Chuyển hướng về trang chủ với tham số verify_token
    // Bot truy cập vào đây sẽ chỉ nhận được lệnh redirect, không làm thay đổi DB
    res.redirect(`/?id=${sid}&verify_token=${t}`);
});

app.post('/api/verify-step', async (req, res) => {
    try {
        const { sessionId, token } = req.body;
        const session = await SessionModel.findOne({ sessionId });

        if (!session) return res.json({ success: false, error: "Session Expired" });
        
        // Kiểm tra Token
        if (session.secretToken !== token) {
            return res.json({ success: false, error: "Invalid Token (Bypass Detected)" });
        }

        // Tăng bước
        session.currentStep += 1;
        
        // Đổi Token mới (Rotate)
        session.secretToken = crypto.randomBytes(16).toString('hex');
        await session.save();

        res.json({ success: true, message: "Step Verified" });
    } catch (e) {
        res.json({ success: false, error: "Internal Error" });
    }
});


// 6. COMPLETE PROCESS (Chỉ cấp key khi đủ bước)
app.post('/api/complete-process', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = await SessionModel.findOne({ sessionId });

        if (!session) return res.json({ success: false, error: "Session Lost" });
        
        // Check bước
        if (session.currentStep < TOTAL_STEPS) {
            return res.json({ success: false, refresh: true }); 
        }

        // Tạo Key
        const randomPart = crypto.randomBytes(20).toString('hex').toUpperCase();
        const newKey = `HAIRKEY_${randomPart}`;
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

        // Update User
        await UserModel.findOneAndUpdate(
            { hwid: session.hwid },
            { key: newKey, keyExpires: expiresAt, $inc: { totalGenerations: 1 } },
            { upsert: true }
        );

        await SessionModel.deleteOne({ sessionId });

        res.json({ success: true, key: newKey });
    } catch (e) { res.json({ success: false, error: e.message }); }
});

// ================= ADMIN ROUTES =================

app.post('/admin/login', (req, res) => {
    const { username, password } = req.body;
    if (username === ADMIN_USER && password === ADMIN_PASS) {
        req.session.isAdmin = true;
        res.json({ success: true });
    } else {
        res.json({ success: false });
    }
});

app.get('/api/admin/users', checkAdminAuth, async (req, res) => {
    const users = await UserModel.find().sort({ lastLogin: -1 }).limit(100);
    res.json(users);
});

// ================= START SERVER =================
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🔗 Domain: ${YOUR_DOMAIN}`);
});