require('dotenv').config();
const { app, connectDB } = require('./app');

const PORT = process.env.PORT || 3000;
connectDB(process.env.DB_URI).then(() => {
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
});
