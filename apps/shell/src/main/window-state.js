const { app } = require('electron');
const path = require('path');
const fs = require('fs');

class WindowState {
  constructor(options) {
    this.windowName = options.windowName || 'main';
    this.width = options.defaultWidth || 1400;
    this.height = options.defaultHeight || 900;
    this.x = undefined;
    this.y = undefined;

    this.stateFilePath = path.join(app.getPath('userData'), 'window-state.json');
    this.state = this.readState();

    if (this.state) {
      this.x = this.state.x;
      this.y = this.state.y;
      this.width = this.state.width;
      this.height = this.state.height;
    }
  }

  readState() {
    try {
      if (fs.existsSync(this.stateFilePath)) {
        const data = fs.readFileSync(this.stateFilePath, 'utf-8');
        return JSON.parse(data);
      }
    } catch (e) {
      // If reading fails, return null and use defaults
    }
    return null;
  }

  saveState() {
    try {
      fs.writeFileSync(this.stateFilePath, JSON.stringify({
        x: this.x,
        y: this.y,
        width: this.width,
        height: this.height,
      }), 'utf-8');
    } catch (e) {
      console.error('Failed to save window state:', e);
    }
  }

  track(window) {
    window.on('moved', () => {
      const [x, y] = window.getPosition();
      this.x = x;
      this.y = y;
      this.saveState();
    });

    window.on('resized', () => {
      const [width, height] = window.getSize();
      this.width = width;
      this.height = height;
      this.saveState();
    });
  }
}

module.exports = WindowState;
