const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
require('dotenv').config();

const locationRoutes = require('./routes/location');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

// Log requests
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Routes
app.use('/', locationRoutes);

// Health Check
app.get('/health', (req, res) => {
    res.json({ status: 'UP', service: 'Odisha Admin Service' });
});

app.listen(PORT, () => {
    console.log(`🚀 Odisha Admin Service running on http://localhost:${PORT}`);
});
