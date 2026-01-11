require('dotenv').config(); // Nạp biến môi trường đầu tiên

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const session = require('express-session');
const crypto = require('crypto');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// === LOAD CONFIG FROM ENV ===
const MONGO_URI = process.env.MONGO_URI;
const YOUR_DOMAIN = process.env.DOMAIN;
const LINKVERTISE_USER_ID = process.env.LINKVERTISE_USER_ID;
const ADMIN_USER = process.env.ADMIN_USER;
const ADMIN_PASS = process.env.ADMIN_PASS;
const SESSION_SECRET = process.env.SESSION_SECRET;

// Validate Config
if (!MONGO_URI || !LINKVERTISE_USER_ID) {
    console.error("❌ CRITICAL ERROR: Missing .env configuration!");
    process.exit(1);
}

// === DATABASE CONNECTION ===
mongoose.connect(MONGO_URI)
    .then(() => console.log('✅ Connected to MongoDB Atlas'))
    .catch(err => console.error('❌ MongoDB Connection Error:', err));

// === DATABASE SCHEMAS ===

// 1. User Schema: Lưu thông tin tài khoản vĩnh viễn theo HWID
const UserSchema = new mongoose.Schema({
    hwid: { type: String, unique: true, required: true },
    key: { type: String, default: null },
    keyExpires: { type: Date, default: null },
    ip: String,
    totalGenerations: { type: Number, default: 0 },
    lastLogin: { type: Date, default: Date.now }
});

// 2. Session Schema: Lưu phiên làm việc tạm thời (Handshake)
// Tự động xóa sau 10 phút (600s) để dọn dẹp rác
const SessionSchema = new mongoose.Schema({
    sessionId: { type: String, unique: true },
    hwid: String,       // Map về User thật
    secretToken: String, // Token chống bypass link
    verified: { type: Boolean, default: false }, // Đã xem quảng cáo chưa?
    createdAt: { type: Date, default: Date.now, expires: 600 } 
});

const UserModel = mongoose.model('User', UserSchema);
const SessionModel = mongoose.model('Session', SessionSchema);

// === MIDDLEWARE ===
app.set('trust proxy', true); // Để lấy đúng IP trên Render
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // Serve giao diện Cyberpunk
app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false } // Đặt true nếu chạy https local (Render tự lo cái này)
}));

// Helper lấy IP
function getClientIp(req) {
    return (req.headers['x-forwarded-for'] || req.socket.remoteAddress).split(',')[0].trim();
}

// Middleware Admin Auth
function checkAdminAuth(req, res, next) {
    if (req.session.isAdmin) next();
    else res.status(403).json({ error: "Unauthorized" });
}

// ================= API ROUTES (CLIENT SIDE) =================

// 1. HANDSHAKE: Script gửi HWID -> Server tạo Session -> Trả về Link Dashboard
app.post('/api/handshake', async (req, res) => {
    try {
        const { hwid } = req.body;
        const ip = getClientIp(req);

        if (!hwid) return res.json({ success: false, error: "Missing HWID" });

        // A. Xử lý User (Tự động đăng ký/cập nhật)
        let user = await UserModel.findOne({ hwid });
        if (!user) {
            user = await UserModel.create({ hwid, ip });
            console.log(`[NEW USER] ${hwid.substring(0, 10)}...`);
        } else {
            user.ip = ip;
            user.lastLogin = Date.now();
            await user.save();
        }

        // B. Tạo Session mới (Để giấu HWID trên URL)
        const sessionId = crypto.randomBytes(12).toString('hex'); // ID công khai
        const secretToken = crypto.randomBytes(16).toString('hex'); // Token bí mật

        await SessionModel.create({ sessionId, hwid, secretToken });

        // Trả về Link sạch
        res.json({ success: true, url: `${YOUR_DOMAIN}/?id=${sessionId}` });

    } catch (error) {
        console.error("Handshake Error:", error);
        res.json({ success: false, error: "Server Internal Error" });
    }
});

// 2. CHECK KEY: Script kiểm tra Key có hợp lệ không
app.get('/api/check-key', async (req, res) => {
    try {
        const { hwid, key } = req.query;
        const user = await UserModel.findOne({ hwid });

        if (!user) return res.json({ valid: false });

        // Kiểm tra Key khớp và Thời hạn
        if (user.key === key && user.keyExpires > new Date()) {
            return res.json({ valid: true });
        }
        
        return res.json({ valid: false });
    } catch (e) { res.json({ valid: false }); }
});

// ================= API ROUTES (WEB FRONTEND) =================

// 3. LOAD PROFILE: Web lấy thông tin hiển thị Dashboard
app.post('/api/profile', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = await SessionModel.findOne({ sessionId });
        if (!session) return res.json({ success: false, error: "Session Invalid/Expired" });

        const user = await UserModel.findOne({ hwid: session.hwid });
        if (!user) return res.json({ success: false, error: "User Not Found" });

        // Logic tính toán trạng thái Key
        let keyStatus = "NONE";
        let timeLeft = 0;

        if (user.key && user.keyExpires > new Date()) {
            keyStatus = "ACTIVE";
            timeLeft = Math.floor((new Date(user.keyExpires) - new Date()) / 1000);
        } else if (user.key) {
            keyStatus = "EXPIRED";
        }

        res.json({
            success: true,
            hwidShort: user.hwid.substring(0, 8) + "...",
            keyStatus: keyStatus,
            currentKey: keyStatus === "ACTIVE" ? user.key : null,
            timeLeft: timeLeft,
            totalGenerations: user.totalGenerations
        });
    } catch (e) { res.json({ success: false, error: e.message }); }
});

// 4. START PROCESS: Tạo Link Linkvertise Dynamic
app.post('/api/start-process', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = await SessionModel.findOne({ sessionId });
        if (!session) return res.json({ success: false, error: "Session Invalid" });

        // Tạo Target URL (Callback về server)
        const targetUrl = `${YOUR_DOMAIN}/api/callback?sid=${sessionId}&t=${session.secretToken}`;
        
        // Mã hóa Base64 theo chuẩn Linkvertise
        const base64Url = Buffer.from(targetUrl).toString('base64');
        
        // Tạo Dynamic Link (Random path để tránh cache)
        const randomPath = Math.floor(Math.random() * 99999);
        const linkvertiseLink = `https://link-to.net/${LINKVERTISE_USER_ID}/${randomPath}/dynamic/?r=${base64Url}`;

        res.json({ success: true, link: linkvertiseLink });
    } catch (e) { res.json({ success: false, error: e.message }); }
});

// 5. CALLBACK: Linkvertise redirect về đây
app.get('/api/callback', async (req, res) => {
    try {
        const { sid, t } = req.query; // sid = sessionId, t = secretToken
        
        const session = await SessionModel.findOne({ sessionId: sid });
        
        if (!session) return res.send("<h1 style='color:red; text-align:center'>SESSION EXPIRED</h1>");
        
        // KIỂM TRA BẢO MẬT: Token phải khớp
        if (session.secretToken !== t) {
            return res.send("<h1 style='color:red; text-align:center'>INVALID TOKEN (BYPASS DETECTED)</h1>");
        }

        // Xác thực thành công
        session.verified = true;
        await session.save();

        // Redirect về Web Dashboard kèm hash #completed
        res.redirect(`/?id=${sid}#completed`);
    } catch (e) { res.send("Internal Error"); }
});

// 6. COMPLETE PROCESS: Web gọi để lấy Key sau khi đã Verified
app.post('/api/complete-process', async (req, res) => {
    try {
        const { sessionId } = req.body;
        const session = await SessionModel.findOne({ sessionId });

        if (!session) return res.json({ success: false, error: "Session Lost" });
        if (!session.verified) return res.json({ success: false, error: "Unverified Action" });

        // Tạo Key Mới (HAIRKEY_XXXX)
        const randomPart = crypto.randomBytes(4).toString('hex').toUpperCase();
        const newKey = `HAIRKEY_${randomPart}`;
        const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 Giờ

        // Cập nhật User
        const user = await UserModel.findOne({ hwid: session.hwid });
        user.key = newKey;
        user.keyExpires = expiresAt;
        user.totalGenerations += 1;
        await user.save();

        // Xóa Session (Dọn dẹp)
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