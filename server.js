// Socket.IO Server for troubleshoot-mac.com
// Run this on your server: node server.js

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Store connected clients
const clients = new Map();
const ACCESS_TOKEN = '9f1013f0';

   // Serve static files
   app.use(express.static(__dirname));

// Serve dashboard.html
app.get('/dashboard', (req, res) => {
    res.sendFile(path.join(__dirname, 'dashboard.html'));
});

app.get('/dashboard.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'dashboard.html'));
});

app.get('/', (req, res) => {
    res.send('Screen Watcher Server Running');
});

// Socket.IO connection handling
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);

    // Handle client registration
    socket.on('register-client', (data) => {
        if (data.token === ACCESS_TOKEN) {
            const clientInfo = {
                id: socket.id,
                hostname: data.hostname || 'Unknown',
                username: data.username || 'Unknown',
                resolution: data.resolution || '1920x1080',
                connectedAt: new Date().toISOString()
            };
            
            clients.set(socket.id, clientInfo);
            console.log('Client registered:', clientInfo);
            
            // Confirm registration
            socket.emit('client-registered', { clientId: socket.id });
            
            // Notify all dashboards about new client
            io.emit('clients-list', Array.from(clients.values()));
        }
    });

    // Handle get-clients request (from dashboard)
    socket.on('get-clients', (data) => {
        if (data.token === ACCESS_TOKEN) {
            socket.emit('clients-list', Array.from(clients.values()));
        }
    });

    // Handle watch-client request (from dashboard)
    socket.on('watch-client', (data) => {
        if (data.token === ACCESS_TOKEN && data.clientId) {
            // Tell the specific client to start streaming
            io.to(data.clientId).emit('start-streaming');
        }
    });

    // Handle screen frames from clients
    socket.on('screen-frame', (data) => {
        if (data.clientId) {
            // Broadcast to all dashboards (or specific dashboard watching this client)
            io.emit('screen-frame', data);
        }
    });

    // Handle disconnect
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
        clients.delete(socket.id);
        // Notify dashboards that client disconnected
        io.emit('clients-list', Array.from(clients.values()));
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Dashboard: http://localhost:${PORT}/dashboard`);
});
