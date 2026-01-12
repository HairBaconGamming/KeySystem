require('dotenv').config();
const mongoose = require('mongoose');

// === CONFIG ===
const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
    console.error("❌ Lỗi: Không tìm thấy MONGO_URI trong file .env");
    process.exit(1);
}

// === SCHEMAS (Copy từ server.js sang để nó hiểu cấu trúc) ===
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
    verified: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now, expires: 600 } 
});

const UserModel = mongoose.model('User', UserSchema);
const SessionModel = mongoose.model('Session', SessionSchema);

// === MAIN LOGIC ===
const resetDatabase = async () => {
    try {
        console.log("⏳ Đang kết nối MongoDB...");
        await mongoose.connect(MONGO_URI);
        console.log("✅ Kết nối thành công.");

        console.log("💥 Đang xóa toàn bộ dữ liệu...");
        
        // XÓA SẠCH 2 BẢNG NÀY
        await UserModel.deleteMany({});
        console.log(" - Đã xóa sạch Users.");
        
        await SessionModel.deleteMany({});
        console.log(" - Đã xóa sạch Sessions.");

        console.log("🎉 DATABASE ĐÃ ĐƯỢC RESET VỀ TRẠNG THÁI MỚI TINH!");
        process.exit(0);
    } catch (err) {
        console.error("❌ Lỗi khi reset:", err);
        process.exit(1);
    }
};

resetDatabase();