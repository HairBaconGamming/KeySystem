// Thêm dòng này ở TRÊN CÙNG của file
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const session = require('express-session');
const crypto = require('crypto');
const path = require('path');

const app = express();
// Lấy Port từ môi trường hoặc mặc định 3000
const PORT = process.env.PORT || 3000; 

// === CẤU HÌNH TỪ .ENV ===
const MONGO_URI = process.env.MONGO_URI;
const YOUR_DOMAIN = process.env.DOMAIN;
const LINKVERTISE_USER_ID = process.env.LINKVERTISE_USER_ID;
const ADMIN_USER = process.env.ADMIN_USER;
const ADMIN_PASS = process.env.ADMIN_PASS;
const SESSION_SECRET = process.env.SESSION_SECRET;

// Kiểm tra xem đã nạp đủ biến chưa (Debug)
if (!MONGO_URI || !LINKVERTISE_USER_ID) {
    console.error("❌ LỖI: Thiếu biến môi trường trong file .env hoặc trên Server!");
    process.exit(1);
}

// === KẾT NỐI DATABASE ===
mongoose.connect(MONGO_URI)
    .then(() => console.log('✅ Connected to MongoDB Atlas via ENV'))
    .catch(err => console.error('❌ MongoDB Error:', err));

// ... (Phần còn lại của code giữ nguyên) ...

// Sửa lại phần session middleware để dùng secret từ env
app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: true
}));

// ... (Các API bên dưới giữ nguyên) ...