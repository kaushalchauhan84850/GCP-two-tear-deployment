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

function forwardAuth(req) {
  return req.headers.authorization
    ? { headers: { Authorization: req.headers.authorization } }
    : {};
}

function handleProxyError(err, res) {
  console.error('Error contacting backend:', err.message);
  const status = err.response?.status || 502;
  const data = err.response?.data || { error: 'Could not reach backend service' };
  res.status(status).json(data);
}

// Public: enrollment form submission
app.post('/api/students', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/students`, req.body);
    res.status(201).json(response.data);
  } catch (err) {
    handleProxyError(err, res);
  }
});

// Admin login
app.post('/api/admin/login', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/admin/login`, req.body);
    res.json(response.data);
  } catch (err) {
    handleProxyError(err, res);
  }
});

// Admin: list students
app.get('/api/admin/students', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/students`, forwardAuth(req));
    res.json(response.data);
  } catch (err) {
    handleProxyError(err, res);
  }
});

// Admin: update a student
app.put('/api/admin/students/:id', async (req, res) => {
  try {
    const response = await axios.put(
      `${BACKEND_URL}/students/${req.params.id}`,
      req.body,
      forwardAuth(req)
    );
    res.json(response.data);
  } catch (err) {
    handleProxyError(err, res);
  }
});

// Admin: delete a student
app.delete('/api/admin/students/:id', async (req, res) => {
  try {
    const response = await axios.delete(
      `${BACKEND_URL}/students/${req.params.id}`,
      forwardAuth(req)
    );
    res.json(response.data);
  } catch (err) {
    handleProxyError(err, res);
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend server listening on port ${PORT}`);
  console.log(`Forwarding API calls to backend at ${BACKEND_URL}`);
});
