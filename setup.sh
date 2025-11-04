#!/bin/bash
# Web Linux KDE Setup Script

echo "Setting up Web Linux KDE project..."

# Initialize npm if needed
if [ ! -f package.json ]; then
    npm init -y
fi

# Install dependencies
npm install express ws node-pty chokidar xterm xterm-addon-fit

# Create directories
mkdir -p public/apps
mkdir -p public/assets

# Create output.txt if missing
#if [ ! -f output.txt ]; then
    #echo "Welcome to your Eaglercraft server!" > output.txt
#fi

# Create server.js
cat > server.js << EOF
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
EOF

# Create index.html
cat > public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Web Linux KDE</title>
<link rel="stylesheet" href="style.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm/css/xterm.css" />
</head>
<body>
<div id="desktop">
    <div id="taskbar">
        <button onclick="openApp('firefox')">Firefox</button>
        <button onclick="openApp('eaglercraft')">Eaglercraft</button>
        <button onclick="openApp('terminal')">Terminal</button>
        <button onclick="openApp('serverlist')">Server List</button>
    </div>
    <div id="windows"></div>
</div>

<script src="https://cdn.jsdelivr.net/npm/xterm/lib/xterm.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit/lib/xterm-addon-fit.js"></script>
<script src="desktop.js"></script>
</body>
</html>
EOF

# Create style.css
cat > public/style.css << EOF
body, html { margin: 0; padding: 0; font-family: sans-serif; height: 100%; overflow: hidden; }
#desktop { width: 100%; height: 100%; position: relative; background-image: url('https://github.com/KDE/breeze/blob/master/wallpapers/Next/contents/images/7680x2160.png?raw=true'); background-size: cover; background-position: center; }
#taskbar { position: absolute; bottom: 0; width: 100%; height: 40px; background: rgba(0,0,0,0.7); display: flex; align-items: center; z-index: 10; }
#taskbar button { margin: 0 5px; padding: 5px 10px; cursor: pointer; }
.window { position: absolute; background: #222; color: #fff; border: 2px solid #555; width: 600px; height: 400px; resize: both; overflow: hidden; z-index: 5; }
.window-header { background: #444; padding: 5px; cursor: move; display: flex; justify-content: space-between; align-items: center; }
.window-content { width: 100%; height: calc(100% - 30px); background: #111; }
.window-controls { display: flex; gap: 5px; }
.window-controls button { width: 20px; height: 20px; border: none; background: #666; color: white; cursor: pointer; font-weight: bold; line-height: 20px; padding: 0; }
EOF

# Create desktop.js
cat > public/desktop.js << EOF
function openApp(app) {
    const windows = document.getElementById('windows');
    const win = document.createElement('div');
    win.classList.add('window');
    win.style.top = '50px';
    win.style.left = '50px';

    const header = document.createElement('div');
    header.classList.add('window-header');

    const title = document.createElement('span');
    title.innerText = app;

    const controls = document.createElement('div');
    controls.classList.add('window-controls');

    const btnMin = document.createElement('button');
    btnMin.innerText = '_';
    btnMin.onclick = () => {
        if(content.style.display !== 'none') {
            content.style.display = 'none';
            win.style.height = '30px';
        } else {
            content.style.display = 'block';
            win.style.height = '400px';
        }
    };

    const btnMax = document.createElement('button');
    btnMax.innerText = '□';
    btnMax.onclick = () => {
        if(win.dataset.maximized === 'true') {
            win.style.top = win.dataset.prevTop;
            win.style.left = win.dataset.prevLeft;
            win.style.width = win.dataset.prevWidth;
            win.style.height = win.dataset.prevHeight;
            win.dataset.maximized = 'false';
        } else {
            win.dataset.prevTop = win.style.top;
            win.dataset.prevLeft = win.style.left;
            win.dataset.prevWidth = win.style.width;
            win.dataset.prevHeight = win.style.height;
            win.style.top = '0';
            win.style.left = '0';
            win.style.width = '100%';
            win.style.height = '100%';
            win.dataset.maximized = 'true';
        }
    };

    const btnClose = document.createElement('button');
    btnClose.innerText = '×';
    btnClose.onclick = () => win.remove();

    controls.appendChild(btnMin);
    controls.appendChild(btnMax);
    controls.appendChild(btnClose);

    header.appendChild(title);
    header.appendChild(controls);
    header.onmousedown = dragMouseDown;

    const content = document.createElement('div');
    content.classList.add('window-content');

    win.appendChild(header);
    win.appendChild(content);
    windows.appendChild(win);

    if(app === 'firefox') {
        const iframe = document.createElement('iframe');
        iframe.src = 'https://example.com';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        content.appendChild(iframe);
    } else if(app === 'eaglercraft') {
        const iframe = document.createElement('iframe');
        iframe.src = 'https://eaglercraft.com';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        content.appendChild(iframe);
    } else if(app === 'terminal') {
        const termDiv = document.createElement('div');
        termDiv.id = 'xterm';
        termDiv.style.width = '100%';
        termDiv.style.height = '100%';
        content.appendChild(termDiv);

        const term = new Terminal();
        const fitAddon = new FitAddon.FitAddon();
        term.loadAddon(fitAddon);
        term.open(termDiv);
        fitAddon.fit();

        const socket = new WebSocket('/terminal');
        term.onData(data => socket.send(data));
        socket.onmessage = e => term.write(e.data);
    } else if(app === 'serverlist') {
        const listDiv = document.createElement('div');
        listDiv.style.padding = '10px';
        listDiv.style.overflowY = 'auto';
        listDiv.style.height = '100%';
        content.appendChild(listDiv);

        fetch('/serverlist').then(r => r.text()).then(data => { listDiv.innerText = data; });
        const ws = new WebSocket('/serverlist-ws');
        ws.onmessage = (e) => { listDiv.innerText = e.data; };
    }

    let offsetX=0, offsetY=0, isDragging=false;
    function dragMouseDown(e){ e.preventDefault(); offsetX=e.clientX-win.offsetLeft; offsetY=e.clientY-win.offsetTop; isDragging=true; document.onmousemove=elementDrag; document.onmouseup=closeDragElement;}
    function elementDrag(e){ if(!isDragging) return; win.style.top=(e.clientY-offsetY)+"px"; win.style.left=(e.clientX-offsetX)+"px";}
    function closeDragElement(){ isDragging=false; document.onmousemove=null; document.onmouseup=null;}
}
EOF

echo "Setup complete! Run 'node server.js' and open http://localhost:3000"

