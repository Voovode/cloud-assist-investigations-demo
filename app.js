const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

// Memory leak simulation - stores data without cleanup
let memoryLeakArray = [];

app.get('/', (req, res) => {
  res.send('Hello from Cloud Run!');
});

app.get('/leak', (req, res) => {
  // Intentionally cause memory growth
  for (let i = 0; i < 100000; i++) {
    memoryLeakArray.push({
      data: new Array(1000).fill('x').join(''),
      timestamp: new Date()
    });
  }
  res.send(`Memory usage: ${process.memoryUsage().heapUsed / 1024 / 1024} MB`);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});