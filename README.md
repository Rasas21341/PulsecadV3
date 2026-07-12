# PulseCAD Desktop App

A desktop application version of PulseCAD built with Electron.

## Features

- Displays your PulseCAD website as a standalone desktop application
- Phone-sized window interface (425 x 912 pixels)
- Cross-platform support (Windows, macOS, Linux)
- Automatic updates support

## Requirements

- Node.js v14+ ([Download](https://nodejs.org/))
- npm (included with Node.js)

## Installation

1. Clone or download this repository
2. Open a terminal/command prompt in the project folder
3. Run:
   ```
   npm install
   ```

## Running the App

**Option 1: Quick Start (Development)**
- Double-click `run.bat` (Windows)
- Or run: `npm start`

**Option 2: Build Installer**
- Double-click `build.bat` (Windows)
- Or run: `npm run build`
- The installer will be created in the `dist` folder

## File Structure

```
├── main.js              # Electron app entry point
├── pulsecad-revamp.html # Main website file
├── package.json         # Project configuration
├── run.bat              # Quick start script
├── build.bat            # Build script
└── node_modules/        # Dependencies (auto-installed)
```

## Configuration

Edit `main.js` to customize:
- Window size
- URL to display
- App window settings

## Troubleshooting

**App won't start:**
- Make sure Node.js is installed: `node -v`
- Delete `node_modules` folder and run `npm install` again
- Ensure the web server is running on `http://localhost:8000`

**Build fails:**
- Delete the `dist` folder and try again
- Make sure you have write permissions in the project folder
- On Windows, run Command Prompt as Administrator

## Development

To modify the app:
1. Edit `main.js` for app configuration
2. Edit `pulsecad-revamp.html` for website content
3. Run `npm start` to test changes

## Building for Other Platforms

To build for macOS or Linux, install the appropriate build tools and run:
```
npm run build
```

## License

MIT

## Support

For issues or questions, please check the [Electron documentation](https://www.electronjs.org/docs).
