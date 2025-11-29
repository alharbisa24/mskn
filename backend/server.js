const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
console.log('🔑 HUGGINGFACE_API_KEY loaded:', !!process.env.HUGGINGFACE_API_KEY);
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const aiRoutes = require('./routes/ai');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Routes
app.use('/api/ai', aiRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'AI API is running' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  console.log(`AI endpoint available at http://localhost:${PORT}/api/ai/ask`);
});

