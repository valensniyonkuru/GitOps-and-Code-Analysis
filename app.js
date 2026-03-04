const express = require("express");
const mongoose = require("mongoose");
const userRoutes = require("./routes/user");
require("dotenv").config();

const app = express();
app.use(express.json());
app.get("/", (req, res) => {
  res.status(200).json({
    message: process.env.APP_MESSAGE || "Simple Web Service is running!",
    version: process.env.APP_VERSION || "1.0.0",
  });
});

app.use("/users", userRoutes);

const connectDB = async (dbUri) => {
  if (!dbUri) {
    console.log("No DB_URI provided, skipping DB connection for sample app.");
    return;
  }
  try {
    await mongoose.connect(dbUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log("Successfully connected to the database");
  } catch (error) {
    console.error("Error connecting to the database", error);
    // process.exit(1);
  }
};

module.exports = { app, connectDB };
