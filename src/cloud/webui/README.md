# Pre-requisites

This web UI is built using the following technologies:
* Bun
* Vite
* SolidJS
* TypeScript

# Development

To start the development server, run the following command from the `src/cloud/webui` directory:

```bash
bun dev
```

This will start the development server.  
Type `o` and hit enter in the terminal to open the web UI in your default browser.  
Any changes you make to the source code will be automatically reflected in the browser.

# Building for Production

To build the web UI for production, run the following command from the `src/cloud/webui` directory:

```bash
bun run build
```

This will create an optimized build of the web UI in the `dist` directory.