const express = require('express');
const axios = require('axios');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.PORT || 3000;
// BACKEND_URL points at the backend VM's INTERNAL IP, e.g. http://10.0.2.5:5000
// The browser never talks to the backend directly - only this server does.
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:5000';

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'frontend', env: process.env.APP_ENV || 'dev' });
});

app.post('/api/students', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/students`, req.body);
    res.status(201).json(response.data);
  } catch (err) {
    console.error('Error contacting backend:', err.message);
    res.status(502).json({ error: 'Could not reach backend service' });
  }
});

app.get('/api/students', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/students`);
    res.json(response.data);
  } catch (err) {
    console.error('Error contacting backend:', err.message);
    res.status(502).json({ error: 'Could not reach backend service' });
  }
});

app.delete('/api/students/:id', async (req, res) => {
  try {
    const response = await axios.delete(`${BACKEND_URL}/students/${req.params.id}`);
    res.json(response.data);
  } catch (err) {
    console.error('Error contacting backend:', err.message);
    const status = err.response?.status || 502;
    res.status(status).json({ error: 'Could not delete record' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend server listening on port ${PORT}`);
  console.log(`Forwarding API calls to backend at ${BACKEND_URL}`);
});
