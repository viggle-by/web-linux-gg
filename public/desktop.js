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
