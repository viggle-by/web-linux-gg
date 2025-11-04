const express = require('express');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');
const pty = require('node-pty');
const chokidar = require('chokidar');

const app = express();
const port = process.env.PORT || 3000;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Endpoint for server list
app.get('/serverlist', (req, res) => {
    fs.readFile('output.txt', 'utf8', (err, data) => {
        if (err) return res.status(500).send('Error reading file');
        res.send(data);
    });
});

// Start server
const server = app.listen(port, () => {
    console.log("Server running at http://localhost:" + port);
});

// WebSocket for terminal
const wss = new WebSocket.Server({ server, path: '/terminal' });
wss.on('connection', (ws) => {
    const shell = process.env.SHELL || (process.platform === 'win32' ? 'powershell.exe' : 'bash');
    const ptyProcess = pty.spawn(shell, [], {
        name: 'xterm-color',
        cols: 80,
        rows: 24,
        cwd: process.env.HOME,
        env: process.env
    });

    ptyProcess.on('data', data => ws.send(data));
    ws.on('message', msg => ptyProcess.write(msg));
    ws.on('close', () => ptyProcess.kill());
});

// WebSocket for live server list updates
const serverListWSS = new WebSocket.Server({ server, path: '/serverlist-ws' });
const watcher = chokidar.watch('output.txt', { persistent: true });

watcher.on('change', () => {
    fs.readFile('output.txt', 'utf8', (err, data) => {
        if (err) return;
        serverListWSS.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(data);
            }
        });
    });
});
