const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5000;
// Set MONGO_URI to your MongoDB Atlas (or other managed Mongo) connection string,
// e.g. mongodb+srv://user:pass@yourcluster.mongodb.net/studentdb
const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('MONGO_URI is not set. Set it as an environment variable.');
  process.exit(1);
}

mongoose.connect(MONGO_URI)
  .then(() => console.log('MongoDB connected:', MONGO_URI))
  .catch((err) => console.error('MongoDB connection error:', err));

const studentSchema = new mongoose.Schema({
  name: { type: String, required: true },
  rollNumber: { type: String, required: true },
  email: { type: String, required: true },
  course: { type: String, required: true },
  phone: { type: String },
  createdAt: { type: Date, default: Date.now }
});

const Student = mongoose.model('Student', studentSchema);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'backend', env: process.env.APP_ENV || 'dev' });
});

// Create a new student record
app.post('/students', async (req, res) => {
  try {
    const student = new Student(req.body);
    await student.save();
    res.status(201).json(student);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// List all students
app.get('/students', async (req, res) => {
  try {
    const students = await Student.find().sort({ createdAt: -1 });
    res.json(students);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend API listening on port ${PORT}`);
});
